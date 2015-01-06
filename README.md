A cellphone is perfect for driving a robot--it has lots of sensors, wireless adapters, etc.

Flamebot is a first whack at a coffeescript framework that can be used to build a dynamic
state machine to drive a robot. It's written as a FirefoxOS application that can run in the
simulator or you can use Firefox to load it onto a FirefoxOS phone.

The sample app included here presents a user interface that lets you drop virtual flags,
calibrate the compass, follow the virtual flag path, shoot a picture. Provided you have
a FirefoxOS phone and the brookstone wifi racer you'll be in business. You see the current
state machine expanded to highlight the current state when it's running. You can also expand
and collapse the hierarchy to see the other states.

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

If you'd like to try this without the car, in the Firefox simulator, change "new BigCar(bot, 500)" to "new Car(bot)".
Then if you hit the stop or drive button, you should see in your debug console a stream of commands like 
drive(0), drive(1), etc.

BSD license

Copyright 2014, 2015 

Brad Midgley
