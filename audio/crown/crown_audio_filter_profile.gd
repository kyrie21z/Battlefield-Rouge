class_name CrownAudioFilterProfile
extends Resource
## Authored chain; duplicate effects per source so radiance is never global.
@export var high_pass: AudioEffectHighPassFilter
@export var low_pass: AudioEffectLowPassFilter
@export var harmonics: AudioEffectDistortion
@export var presence: AudioEffectHighShelfFilter
@export var plate: AudioEffectReverb
