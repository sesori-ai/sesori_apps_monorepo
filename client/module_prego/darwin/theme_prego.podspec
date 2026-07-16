Pod::Spec.new do |s|
  s.name = 'theme_prego'
  s.version = '0.1.0'
  s.summary = 'Native iOS renderer for the Prego design system.'
  s.description = 'Native iOS renderer used by Prego Flutter components.'
  s.homepage = 'https://github.com/sesori-ai/sesori_apps_monorepo'
  s.license = { :type => 'Proprietary' }
  s.author = { 'Sesori' => 'hello@sesori.ai' }
  s.source = { :path => '.' }
  s.source_files = 'theme_prego/Sources/theme_prego/**/*.swift'
  s.ios.dependency 'Flutter'
  s.ios.deployment_target = '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
