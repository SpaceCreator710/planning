Pod::Spec.new do |s|
  s.name           = 'CapacityHealth'
  s.version        = '1.0.0'
  s.summary        = 'Consent-first HealthKit bridge for AI Plan Your Day'
  s.description    = 'Reads user-authorized sleep, movement, heart-rate and workout summaries.'
  s.author         = 'AI Plan Your Day'
  s.homepage       = 'https://ai-plan-your-day.app'
  s.platforms      = { :ios => '16.0' }
  s.source         = { :git => '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'HealthKit'
  s.source_files = '**/*.{h,m,mm,swift}'
end
