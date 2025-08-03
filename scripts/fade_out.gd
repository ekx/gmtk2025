extends Control

func fade_out(duration: float = 2.0, fade_time: float = 1.0):
	# Create tween for fade out
	var tween = create_tween()
	
	# Wait for duration, then fade out
	tween.tween_interval(duration - fade_time)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	
	# Hide the label when fade is complete
	tween.tween_callback(func(): self.visible = false)

# Example usage
func _ready():
	fade_out(5.0, 2.0)
