# frozen_string_literal: true

# Intercepts POST /api/batch, fans out sub-requests through the full Rack stack,
# and returns aggregated responses. Auth context is inherited from the outer request.
#
# Auth is enforced at the batch level: if the outer request has no Authorization
# header (and DISABLE_AUTH is not set), the batch returns 401 immediately.
class BatchRequestMiddleware
  BATCH_PATH = '/api/batch'
  MAX_BATCH_SIZE = 100

  # Env keys that are request-specific and must not be copied to sub-requests.
  SKIP_KEYS = %w[
    REQUEST_METHOD PATH_INFO QUERY_STRING REQUEST_URI
    rack.input rack.errors CONTENT_TYPE CONTENT_LENGTH
    HTTP_AUTHORIZATION HTTP_X_SIDECAR_TOKEN
    action_dispatch.request_id
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == BATCH_PATH

    return unauthorized_response unless authenticated?(env)

    body = read_body(env)
    parsed = JSON.parse(body)
    requests = parsed.is_a?(Hash) ? parsed['requests'] : nil

    unless requests.is_a?(Array) && requests.size <= MAX_BATCH_SIZE
      return error_response(422, requests.is_a?(Array) ? "Batch size exceeds maximum of #{MAX_BATCH_SIZE}" : 'Invalid requests array')
    end

    responses = requests.map { |req| dispatch(env, req) }
    [200, { 'Content-Type' => 'application/json' }, [{ responses: responses }.to_json]]
  rescue JSON::ParserError
    error_response(422, 'Malformed JSON')
  end

  private

  # Returns true if the request has an Authorization or X-Sidecar-Token header,
  # or if DISABLE_AUTH is set in development.
  def authenticated?(env)
    return true if Rails.env.development? && ENV['DISABLE_AUTH'] == 'true'

    env['HTTP_AUTHORIZATION'].present? || env['HTTP_X_SIDECAR_TOKEN'].present?
  end

  def read_body(env)
    input = env['rack.input']
    input.rewind if input.respond_to?(:rewind)
    body = input.read
    input.rewind if input.respond_to?(:rewind)
    body
  end

  def dispatch(outer_env, req)
    method = req['method']&.upcase || 'GET'
    url    = req['url'] || '/'
    body   = req['body']

    sub_env = build_sub_env(outer_env, method, url, body)
    status, headers, response_body = @app.call(sub_env)

    response_body_str = response_body.respond_to?(:each) ? response_body.to_a.join : response_body.to_s
    parsed_body = begin
      JSON.parse(response_body_str)
    rescue JSON::ParserError
      response_body_str
    end

    { status: status, headers: headers.to_h, body: parsed_body }
  rescue StandardError => e
    # Sub-request errors are isolated — one failure must not abort the batch.
    { status: 500, headers: {}, body: { error: e.message } }
  ensure
    response_body.close if response_body.respond_to?(:close)
  end

  def build_sub_env(outer_env, method, url, body)
    uri = URI.parse(url)
    body_str = body ? body.to_json : ''

    # Start with a clean env for the sub-request path/method/body
    env = Rack::MockRequest.env_for(
      uri.path,
      method: method,
      params: uri.query || '',
      input: StringIO.new(body_str),
      'CONTENT_TYPE' => 'application/json',
      'CONTENT_LENGTH' => body_str.bytesize.to_s
    )

    # Inherit stable env keys from the outer request (session, middleware state, etc.)
    # so the sub-request has the same Rails context as the outer request.
    outer_env.each do |key, value|
      env[key] = value unless SKIP_KEYS.include?(key) || env.key?(key)
    end

    # Inherit auth headers explicitly (they are in SKIP_KEYS to avoid double-setting)
    %w[HTTP_AUTHORIZATION HTTP_X_SIDECAR_TOKEN].each do |key|
      env[key] = outer_env[key] if outer_env[key]
    end

    env
  end

  def unauthorized_response
    body = { error: 'Unauthorized' }.to_json
    [401, { 'Content-Type' => 'application/json', 'Content-Length' => body.bytesize.to_s }, [body]]
  end

  def error_response(status, message)
    body = { error: message }.to_json
    [status, { 'Content-Type' => 'application/json', 'Content-Length' => body.bytesize.to_s }, [body]]
  end
end
