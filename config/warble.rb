Warbler::Config.new do |config|
  config.features       = %w[ compiled ]
  config.dirs           = %w[ config bin lib vendor ]
  config.includes       = FileList['Rakefile', 'VERSION', 'LICENSE.txt']
  config.jar_name       = 'pdba'
  config.bundle_without = []
end