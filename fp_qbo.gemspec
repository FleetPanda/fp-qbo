require_relative "lib/fp_qbo/version"

Gem::Specification.new do |spec|
  spec.name = "fp_qbo"
  spec.version = FpQbo::VERSION
  spec.authors = ["aayushhum"]
  spec.email = ["aayush.h@fleetpanda.com"]

  spec.summary = "Stateless QuickBooks Online API integration gem."
  spec.description = "A production-ready, framework-agnostic gem for seamless QuickBooks Online API integration with multi-tenancy support"
  spec.homepage = "https://github.com/aayushhum/fp-qbo"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # REMOVE this line (causes issues with local builds)
  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/aayushhum/fp-qbo"
  spec.metadata["changelog_uri"] = "https://github.com/aayushhum/fp-qbo/blob/master/CHANGELOG.md"

  # FIX: Include all Ruby files in lib/
  spec.files = Dir["lib/**/*.rb"] + ["README.md", "CHANGELOG.md", "LICENSE.txt"].select { |f| File.exist?(f) }

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
