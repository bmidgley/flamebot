A cellphone is perfect for driving a robot--it has lots of sensors, wireless adapters, etc.

Flamebot is a first whack at a coffeescript framework that can be used to build a dynamic
state machine to drive a robot. 

It should soon be ready for a refactor as we're still experimenting to see what patterns 
work when writing for it.

I presented this in a talk: https://plus.google.com/events/cv4v1h4g1edp0j9abht62ma2bfg

Add events:

* send events via web app (wifi racer blocks internet access, so possibly add a server to the car's wan)
* accelerometer for rising, falling, terrain info
* microphone input, tones or loud noise
* read QR codes with camera to detect position
* image processing to estimate speed, terrain, find targets
* IR channel for special targets that are IR bright

More refactoring:

* simplify goals handling -- one item not array, use the state name, move out of core framework, etc
* work again on prototype gui, somehow link to the active state machine
* gui should display current state and useful information about the machine
* start/stop sounds to indicate state or as an action available on entering

BSD license
Copyright 2014 Brad Midgley
