A cellphone is perfect for driving a robot--it has lots of sensors, wireless adapters, etc.

Flamebot is a first whack at a coffeescript framework that can be used to build a dynamic
state machine to drive a robot. 

It should soon be ready for a refactor as we're still experimenting to see what patterns 
work when writing for it.

I presented this in a talk: https://plus.google.com/events/cv4v1h4g1edp0j9abht62ma2bfg

Add events:

* read QR codes with camera to detect position
* image processing to estimate speed, terrain, find targets
* send events via web app (workarounds for wifi car that blocks internet access)
* microphone input, tones or loud noise (produce sound to interact)
* accelerometer for rising, falling, terrain info
* IR channel for special targets that are IR bright

BSD license
Copyright 2014 Brad Midgley
