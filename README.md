A cellphone is perfect for driving a robot--it has lots of sensors, wireless adapters, etc.

Flamebot is a first whack at a coffeescript framework that can be used to build a dynamic
state machine to drive a robot. 

It should soon be ready for a refactor as we're still experimenting to see what patterns 
work when writing for it.

You need to run a coffeescript compiler if you're going to edit the code: coffee -bcw --output . src/

I presented an early version in a talk: https://plus.google.com/events/cv4v1h4g1edp0j9abht62ma2bfg

Add:

* send events via web app (wifi racer blocks internet access, so possibly add a server to the car's wan)
* accelerometer for rising, falling, terrain info
* microphone input, tones or loud noise
* read QR codes with camera to detect position
* image processing to estimate speed, terrain, find targets
* IR channel for special targets that are IR bright
* more robo states for the toolbox
* start/stop sounds to indicate state or as an action available on entering
* write a state machine factory that uses user input and can produce a usable state machine

If you'd like to try this without the car, in the firefox simulator

Change "new BigCar(bot, 500)" to "new Car(bot)"

Then if you hit the drive button, you should see in your debug console a stream of commands like 
drive(0), drive(1), etc.

BSD license

Copyright 2014, 2015 

Brad Midgley
