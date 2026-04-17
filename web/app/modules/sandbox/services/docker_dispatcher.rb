# frozen_string_literal: true

require "open3"

module Sandbox
  # Shells out to `docker run --rm` and records the result as a ContainerRun.
  # Command is passed as an argument array — never interpolated through a shell.
  class DockerDispatcher
    DEFAULT_TIMEOUT = 300 # seconds

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    # @param image [String] Docker image to run
    # @param command [Array<String>] Command + args (no shell interpolation)
    # @param env [Hash] Environment variables to pass to the container
    # @param org_id [String] UUID of the owning org
    # @return [Hash] { exit_code:, stdout:, stderr:, duration_ms: }
    def dispatch(image:, command:, env: {}, org_id:)
      container_run = ContainerRun.create!(
        org_id: org_id,
        image: image,
        command: command.join(" "),
        status: "running",
        started_at: Time.current
      )

      args = build_args(image, command, env)
      log_dispatch(image, command, env)

      stdout, stderr, exit_code = execute(args)
      finished_at = Time.current

      final_status = exit_code == 0 ? "complete" : "failed"
      container_run.update!(
        status: final_status,
        exit_code: exit_code,
        stdout: stdout,
        stderr: stderr,
        finished_at: finished_at
      )

      { exit_code: exit_code, stdout: stdout, stderr: stderr, duration_ms: container_run.duration_ms }
    end

    private

    def build_args(image, command, env)
      args = ["docker", "run", "--rm"]
      env.each do |key, value|
        raw = value.is_a?(Secret) ? value.expose : value.to_s
        args.push("-e", "#{key}=#{raw}")
      end
      args.push(image, *command)
    end

    def execute(args)
      pid = nil
      stdout, stderr, status = nil

      begin
        Timeout.timeout(@timeout) do
          stdout, stderr, status = Open3.capture3(*args)
        end
        [stdout, stderr, status.exitstatus]
      rescue Timeout::Error
        Process.kill("KILL", pid) if pid
        [stdout.to_s, "#{stderr}Process killed: timeout after #{@timeout}s", 137]
      end
    end

    def log_dispatch(image, command, env)
      safe_env = env.transform_values { |v| v.is_a?(Secret) ? "[REDACTED]" : v.to_s }
      Rails.logger.info("[Sandbox::DockerDispatcher] image=#{image} command=#{command.inspect} env=#{safe_env.inspect}")
    end
  end
end
