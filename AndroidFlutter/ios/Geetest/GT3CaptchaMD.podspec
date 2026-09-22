Pod::Spec.new do |s|
  s.name = 'GT3CaptchaMD'
  s.version = '0.15.9'
  s.summary = 'Official GeeTest v3 XCFramework for Newbili MD.'
  s.homepage = 'https://github.com/GeeTeam/gt3-spm-repo'
  s.license = { :type => 'MIT' }
  s.author = 'GeeTest'
  s.source = { :git => 'https://github.com/GeeTeam/gt3-spm-repo.git',
               :commit => '2f109b127c2988660a21b405b3c77fb5022893d8' }
  s.platform = :ios, '15.0'
  s.frameworks = 'WebKit'
  s.vendored_frameworks = 'Sources/GT3Captcha.xcframework'
  s.resources = 'GT3Captcha.bundle'
end
