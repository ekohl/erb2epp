Gem::Specification.new do |s|
  s.name        = 'erb2epp'
  s.version     = '0.1.0'
  s.licenses    = ['MIT']
  s.summary     = 'Convert Ruby ERB templates to Puppet EPP'
  s.description = <<~DESC
    This tool aims to convert the templates and rewrite the syntax where
    needed. It also provides a list of variables used, which makes it easy to
    add data types for additional validation and provide the context to the
    template.
  DESC
  s.authors     = ['Ewoud Kohl van Wijngaarden']
  s.email       = 'ewoud+rubygems@kohlvanwijngaarden.nl'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*'] + ['LICENSE']
  s.homepage    = 'https://github.com/ekohl/erb2epp'
  s.metadata    = { 'source_code_uri' => 'https://github.com/ekohl/erb2pp' }
  s.executables << 'erb2epp'

  s.required_ruby_version = '>= 2.7.0', '< 4'

  s.add_runtime_dependency 'temple', '~> 0.10.0'
end
