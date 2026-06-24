
Pod::Spec.new do |s|
  s.name          = "MahaPagingCore"
  s.version       = "0.1.1"
  s.summary       = "Maha paging container components."
  s.homepage      = "https://github.com/wangweiqi864-hue/MahaPagingCore"
  s.license       = "MIT"
  s.author        = { "wangweiqi864-hue" => "317437084@qq.com" }
  s.platform      = :ios, "11.0"
  s.swift_version = "5.0"
  s.source        = { :git => "ssh://git@github.com/wangweiqi864-hue/MahaPagingCore.git", :tag => s.version.to_s }
  s.framework     = "UIKit"
  s.source_files  = "MahaPagingCore/Sources/**/*.{swift}"
  s.requires_arc  = true
end
