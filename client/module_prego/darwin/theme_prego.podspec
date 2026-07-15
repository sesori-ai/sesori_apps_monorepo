Pod::Spec.new do |s|
  s.name = 'theme_prego'
  s.version = '0.1.0'
  s.summary = 'Native platform renderers for the Prego design system.'
  s.description = 'Native platform renderers used by Prego Flutter components.'
  s.homepage = 'https://github.com/sesori-ai/sesori_apps_monorepo'
  s.license = { :type => 'Proprietary' }
  s.author = { 'Sesori' => 'hello@sesori.ai' }
  s.source = { :path => '.' }
  s.source_files = 'theme_prego/Sources/theme_prego/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
