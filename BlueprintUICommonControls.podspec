Pod::Spec.new do |s|
  s.name         = 'BlueprintUICommonControls'
  s.version      = '0.12.0'
  s.summary      = 'UIKit-backed elements for Blueprint'
  s.homepage     = 'https://www.github.com/square/blueprint'
  s.license      = 'Apache License, Version 2.0'
  s.author       = 'Square'
  s.source       = { :git => 'https://github.com/square/blueprint.git', :tag => s.version }

  s.swift_version = '5.1'

  s.ios.deployment_target = '10.0'

  s.source_files = 'BlueprintUICommonControls/Sources/**/*.swift'

  s.dependency 'BlueprintUI'
end
