# frozen_string_literal: true

# Intercepts GET /health before all other middleware.
# Returns 200 when DB is reachable, 503 otherwise. Body is always empty.
class HealthCheckMiddleware
  HEALTH_PATH = '/health'

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO'] == HEALTH_PATH

    ActiveRecord::Base.connection.execute('SELECT 1')
    [200, { 'Content-Type' => 'text/plain', 'Content-Length' => '0' }, []]
  rescue StandardError
    [503, { 'Content-Type' => 'text/plain', 'Content-Length' => '0' }, []]
  end
end
