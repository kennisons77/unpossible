# frozen_string_literal: true

# Rate limiting via rack-attack. Throttle all requests by IP.
# Returns 429 Too Many Requests when limit is exceeded.
class Rack::Attack
  # 300 requests per 5 minutes per IP
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Stricter limit on auth endpoint: 10 per minute per IP
  throttle("auth/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/auth/token" && req.post?
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" }, ['{"error":"Too Many Requests"}']]
  end
end
