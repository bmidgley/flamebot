A cellphone is perfect for driving a robot--it has lots of sensors, wireless adapters, etc.

Flamebot is a first whack at a coffeescript framework that can be used to build a dynamic
state machine to drive a robot. 

It should soon be ready for a refactor as we're still experimenting to see what patterns 
work when writing for it.

You need to run a coffeescript compiler if you're going to edit the code: coffee -bcw --output . src/

I presented this in a talk: https://plus.google.com/events/cv4v1h4g1edp0j9abht62ma2bfg

Add:

* send events via web app (wifi racer blocks internet access, so possibly add a server to the car's wan)
* accelerometer for rising, falling, terrain info
* microphone input, tones or loud noise
* read QR codes with camera to detect position
* image processing to estimate speed, terrain, find targets
* IR channel for special targets that are IR bright
* repeat-n-times state
* more states for the toolbox

More refactoring:

* simplify goals handling -- one item not array, use the state name, move out of core framework, etc
* work again on prototype gui, somehow link to the active state machine
* gui should display current state and useful information about the machine
* start/stop sounds to indicate state or as an action available on entering

If you'd like to try this without the car, run this in your console:

nc -l -p 9000

And change "new BigCar(bot, 500)" to "new BigCar(bot, 500, '127.0.0.1')"

Then if you hit the drive button, you should see in your nc output a stream of commands like 
$89476$?$39476$?$89476$?$39476$?$89476$?.

BSD license
Copyright 2014 
Brad Midgley
