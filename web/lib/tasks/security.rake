# frozen_string_literal: true

namespace :security do
  desc "Run brakeman static analysis (exits non-zero on warnings)"
  task :brakeman do
    require "brakeman"
    result = Brakeman.run(
      app_path: Rails.root.to_s,
      print_report: true,
      quiet: false
    )
    abort "Brakeman found warnings" if result.warnings.any?
  end

  desc "Run bundler-audit to check for vulnerable gems"
  task :bundler_audit do
    require "bundler/audit/cli"
    Bundler::Audit::CLI.start(["check", "--update"])
  end
end
