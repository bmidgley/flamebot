// Generated by CoffeeScript 1.8.0
var Announcer, BigCar, ButtonAnnouncer, ButtonWatcher, CompassAnnouncer, CompassCalibrator, CrashAnnouncer, ImaginaryCar, LittleCar, LocationAnnouncer, OrientationAnnouncer, RobotBatteryLimit, RobotFindingState, RobotFlaggingState, RobotLoopState, RobotPhotographingState, RobotSequentialState, RobotState, RobotTestMachine, RobotTimeLimit, StateTracker, TimeAnnouncer, bot, timer_id,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

RobotState = (function() {
  function RobotState(name, goals, listener, entering) {
    this.name = name;
    this.goals = goals;
    this.listener = listener;
    this.entering = entering;
    this.behaviors = [];
    this.parent = null;
    this.addForward = true;
  }

  RobotState.prototype.addChild = function(state) {
    state.parent = this;
    if (this.addForward) {
      this.behaviors.push(state);
    } else {
      this.behaviors.unshift(state);
    }
    return state;
  };

  RobotState.prototype.processEvent = function(currentState, event) {
    var newState;
    if (this.parent) {
      newState = this.parent.processEvent(currentState, event);
      if (newState) {
        return newState;
      }
    }
    if (this.listener) {
      newState = this.listener(currentState, event, this);
      if (newState) {
        return newState;
      }
    }
    return null;
  };

  RobotState.prototype.enterAll = function(oldState, currentState, bot) {
    if (this.parent) {
      this.parent.enterAll(oldState, currentState, bot);
    }
    if (this.entering) {
      return this.entering(oldState, currentState, this, bot);
    }
  };

  RobotState.prototype.findHandler = function(goal) {
    return this.ancestor().findHandlerR(goal);
  };

  RobotState.prototype.findHandlerR = function(goal) {
    var behavior, found, _i, _len, _ref;
    if (__indexOf.call(this.goals, goal) >= 0) {
      return this;
    }
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      behavior = _ref[_i];
      found = behavior.findHandlerR(goal);
      if (found) {
        return found;
      }
    }
    return null;
  };

  RobotState.prototype.ancestor = function() {
    if (!this.parent) {
      return this;
    }
    return this.parent.ancestor();
  };

  RobotState.prototype.contains = function(target) {
    var child, _i, _len, _ref;
    if (target === this) {
      return true;
    }
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      if (child.contains(target)) {
        return true;
      }
    }
    return false;
  };

  RobotState.prototype.toRadians = function(r) {
    return r * Math.PI / 180.0;
  };

  RobotState.prototype.toDegrees = function(d) {
    return 180.0 * d / Math.PI;
  };

  RobotState.prototype.bearing = function(a, b) {
    var lat1, lat2, lon1, lon2, x, y;
    lat1 = this.toRadians(a.latitude);
    lat2 = this.toRadians(b.latitude);
    lon1 = this.toRadians(a.longitude);
    lon2 = this.toRadians(b.longitude);
    y = Math.sin(lon2 - lon1) * Math.cos(lat2);
    x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(lon2 - lon1);
    return this.toDegrees(Math.atan2(y, x));
  };

  RobotState.prototype.accordian = function(target, event) {
    var child, collapsed, x, _i, _len, _ref;
    collapsed = target !== this && this.contains(target) ? "false" : "true";
    x = "<div data-role='collapsible' data-collapsed='" + collapsed + "' data-theme='b'><h3>" + (target === this ? "*" + this.name + event : this.name) + "</h3>";
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      x += child.accordian(target, event);
    }
    x += '</div>';
    return x;
  };

  return RobotState;

})();

RobotLoopState = (function(_super) {
  __extends(RobotLoopState, _super);

  function RobotLoopState(name, goals) {
    RobotLoopState.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (currentState !== this) {
        return null;
      }
      return this.behaviors[0] || this.parent;
    });
  }

  return RobotLoopState;

})(RobotState);

RobotSequentialState = (function(_super) {
  __extends(RobotSequentialState, _super);

  function RobotSequentialState(name, goals) {
    this.counter = -1;
    RobotSequentialState.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (currentState !== this) {
        return null;
      }
      return this.behaviors[this.counter] || this.parent;
    }, (function(_this) {
      return function(oldState, currentState) {
        var contained;
        if (currentState !== _this) {
          return;
        }
        contained = _this.contains(oldState);
        return _this.counter = contained ? _this.counter + 1 : 0;
      };
    })(this));
  }

  RobotSequentialState.prototype.addChild = function(state) {
    state.name += " " + (this.behaviors.length + 1);
    return RobotSequentialState.__super__.addChild.call(this, state);
  };

  return RobotSequentialState;

})(RobotState);

RobotTimeLimit = (function(_super) {
  __extends(RobotTimeLimit, _super);

  function RobotTimeLimit(name, goals, duration) {
    this.duration = duration;
    this.elapsed = 0;
    RobotTimeLimit.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (currentState === this) {
        if (this.contained) {
          return this.parent;
        } else {
          return this.behaviors[0] || this.parent;
        }
      }
      if (event.timer) {
        this.elapsed += event.timer;
        if (this.elapsed > this.duration) {
          this.elapsed = 0;
          return this.parent;
        }
      }
      return null;
    }, (function(_this) {
      return function(oldState, currentState) {
        _this.contained = _this.contains(oldState);
        if (!_this.contained) {
          return _this.elapsed = 0;
        }
      };
    })(this));
  }

  return RobotTimeLimit;

})(RobotState);

RobotFlaggingState = (function(_super) {
  __extends(RobotFlaggingState, _super);

  function RobotFlaggingState(driver, name, flagname, goals, target) {
    this.target = target;
    RobotFlaggingState.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (event.location) {
        this.target.addChild(new RobotFindingState(driver, flagname, [], event.location.coords));
        return this.parent;
      }
      return null;
    });
  }

  return RobotFlaggingState;

})(RobotState);

RobotPhotographingState = (function(_super) {
  __extends(RobotPhotographingState, _super);

  function RobotPhotographingState(name, goals, filename) {
    this.filename = filename;
    RobotPhotographingState.__super__.constructor.call(this, name, goals, function(currentState, event) {
      return this.parent;
    }, (function(_this) {
      return function(oldState, currentState) {
        var cname, options;
        if (currentState !== _this) {
          return;
        }
        cname = navigator.mozCameras.getListOfCameras()[0];
        options = {
          camera: cname
        };
        console.log("selected Camera: " + cname);
        return navigator.mozCameras.getCamera(options, function(camera) {
          var poptions;
          console.log(camera);
          poptions = {
            rotation: 90,
            pictureSize: camera.capabilities.pictureSizes[0],
            fileFormat: camera.capabilities.fileFormats[0]
          };
          console.log(poptions);
          return camera.takePicture(poptions, function(blob) {
            console.log(blob);
            return navigator.getDeviceStorage('pictures').addNamed(blob, _this.filename);
          });
        }, function(e) {
          return console.log(e);
        });
      };
    })(this));
  }

  return RobotPhotographingState;

})(RobotState);

RobotFindingState = (function(_super) {
  __extends(RobotFindingState, _super);

  function RobotFindingState(driver, basename, goals, location, perimeter, compass_variance) {
    this.driver = driver;
    this.basename = basename;
    this.location = location;
    this.perimeter = perimeter != null ? perimeter : 3;
    this.compass_variance = compass_variance != null ? compass_variance : 20;
    RobotFindingState.__super__.constructor.call(this, this.basename, goals, function(currentState, event) {
      var d, declination, distance, newState;
      if (event.location) {
        this.current_location = event.location.coords;
        distance = this.distance(this.current_location, this.location);
        if (distance < this.perimeter) {
          return this.parent;
        }
      }
      if (event.orientation) {
        declination = 13;
        this.compass_reading = (360 - event.orientation.alpha) % 360;
        if (this.debug) {
          console.log("true orientation: " + this.compass_reading);
          this.debug = false;
        }
      }
      if (event.timer) {
        this.debug = false;
        this.debug2 = false;
      }
      newState = this;
      d = this.correction();
      if (d > this.compass_variance) {
        newState = this.left_turning;
      }
      if (d < -this.compass_variance) {
        newState = this.right_turning;
      }
      if (currentState === newState) {
        return null;
      }
      return newState;
    }, (function(_this) {
      return function(oldState, currentState) {
        if (currentState === _this) {
          return _this.driver.drive(1);
        }
      };
    })(this));
    this.left_turning = this.addChild(new RobotState("left", [], (function() {
      return null;
    }), ((function(_this) {
      return function() {
        return _this.driver.drive(5);
      };
    })(this))));
    this.right_turning = this.addChild(new RobotState("right", [], (function() {
      return null;
    }), ((function(_this) {
      return function() {
        return _this.driver.drive(6);
      };
    })(this))));
  }

  RobotFindingState.prototype.toRadians = function(r) {
    return r * Math.PI / 180.0;
  };

  RobotFindingState.prototype.toDegrees = function(d) {
    return 180.0 * d / Math.PI;
  };

  RobotFindingState.prototype.correction = function() {
    var bearing, relative;
    if (!this.compass_reading) {
      return 0;
    }
    if (!this.current_location) {
      return 0;
    }
    bearing = this.bearing(this.current_location, this.location);
    relative = (360 + this.compass_reading - bearing) % 360;
    if (relative > 180) {
      relative -= 360;
    }
    this.name = "" + this.basename + (Math.round(this.compass_reading)) + "/" + (Math.round(bearing)) + "/" + (Math.round(relative)) + " " + (Math.round(this.distance(this.current_location, this.location))) + "m";
    if (this.debug2) {
      console.log("bearing " + bearing + " from compass " + this.compass_reading + " off by " + relative + ". " + this.current_location.latitude + "," + this.current_location.longitude + " to " + this.location.latitude + "," + this.location.longitude + " " + (this.distance(this.current_location, this.location)) + "m");
      this.debug2 = false;
    }
    return relative;
  };

  RobotFindingState.prototype.distance = function(a, b, r) {
    var d, lat1, lat2, lon1, lon2, n;
    if (r == null) {
      r = 6371000;
    }
    lat1 = this.toRadians(a.latitude);
    lat2 = this.toRadians(b.latitude);
    lon1 = this.toRadians(a.longitude);
    lon2 = this.toRadians(b.longitude);
    n = (Math.pow(Math.sin((lat2 - lat1) / 2), 2)) + Math.cos(lat1) * Math.cos(lat2) * (Math.pow(Math.sin((lon2 - lon1) / 2), 2));
    d = 2 * r * Math.atan2(Math.sqrt(n), Math.sqrt(1 - n));
    return d;
  };

  return RobotFindingState;

})(RobotState);

RobotBatteryLimit = (function(_super) {
  __extends(RobotBatteryLimit, _super);

  function RobotBatteryLimit(name, goals, threshold) {
    this.threshold = threshold;
    RobotBatteryLimit.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (event.battery && event.battery < this.threshold) {
        return this.parent;
      }
      return null;
    });
  }

  return RobotBatteryLimit;

})(RobotState);

ButtonWatcher = (function(_super) {
  __extends(ButtonWatcher, _super);

  function ButtonWatcher(name, goals, entering) {
    ButtonWatcher.__super__.constructor.call(this, name, goals, function(currentState, event) {
      if (event.button) {
        return currentState.findHandler(event.button);
      }
      return null;
    }, entering);
  }

  return ButtonWatcher;

})(RobotState);

CompassCalibrator = (function(_super) {
  __extends(CompassCalibrator, _super);

  function CompassCalibrator(name, goals, driver) {
    this.driver = driver;
    CompassCalibrator.__super__.constructor.call(this, name, goals, function(currentState, event) {
      var temp;
      if (this.complete) {
        this.complete = false;
        temp = this.previousState;
        this.previousState = null;
        return temp;
      }
      if (this.sequence.contains(currentState)) {
        return null;
      }
      return this.sequence;
    }, (function(_this) {
      return function(oldState, currentState, calibrator, bot) {
        if (currentState !== _this) {
          return;
        }
        _this.driver.drive(0);
        if (_this.location2) {
          _this.calibrated = bot.addAnnouncer(new CompassAnnouncer("compass", 0, 0));
          _this.complete = true;
          _this.reset();
        }
        if (!_this.contains(oldState)) {
          return _this.previousState || (_this.previousState = oldState);
        }
      };
    })(this));
    this.sequence = this.addChild(new RobotSequentialState("measuring", []));
    (this.sequence.addChild(new RobotTimeLimit("drivelimiting", [], 4))).addChild(new RobotState("driving", [], (function(_this) {
      return function(currentState, event) {
        if (event.location) {
          _this.location1 || (_this.location1 = event.location);
          _this.location2 = event.location;
        }
        if (event.orientation) {
          _this.readings1.push(event.orientation);
        }
        return null;
      };
    })(this), (function(_this) {
      return function() {
        return _this.driver.drive(1);
      };
    })(this)));
    (this.sequence.addChild(new RobotTimeLimit("turnlimiting", [], 8))).addChild(new RobotState("turning", [], (function(_this) {
      return function(currentState, event) {
        if (event.orientation) {
          _this.readings2.push(event.orientation);
        }
        return null;
      };
    })(this), (function(_this) {
      return function() {
        return _this.driver.drive(5);
      };
    })(this)));
    this.reset();
  }

  CompassCalibrator.prototype.reset = function() {
    this.readings1 = [];
    this.readings2 = [];
    this.location1 = null;
    return this.location2 = null;
  };

  return CompassCalibrator;

})(RobotState);

StateTracker = (function() {
  function StateTracker(notifier) {
    this.notifier = notifier;
    this.announcers = {};
  }

  StateTracker.prototype.setState = function(state, oldState, event) {
    this.state = state;
    this.state.enterAll(oldState, this.state, this);
    if (this.notifier) {
      return this.notifier(this.state, event);
    }
  };

  StateTracker.prototype.announce = function(event) {
    var newState;
    if (!this.state) {
      return;
    }
    newState = this.state.processEvent(this.state, event);
    if (newState) {
      return this.setState(newState, this.state, event);
    }
  };

  StateTracker.prototype.addAnnouncer = function(announcer) {
    var previous;
    previous = this.announcers[announcer.name];
    if (previous) {
      previous.setBot(null);
    }
    announcer.setBot(this);
    return this.announcers[announcer.name] = announcer;
  };

  return StateTracker;

})();

ImaginaryCar = (function() {
  function ImaginaryCar(bot) {
    this.bot = bot;
  }

  ImaginaryCar.prototype.drive = function(code) {
    console.log("drive(" + code + ")");
    return this.announce({
      battery: 11
    });
  };

  return ImaginaryCar;

})();

LittleCar = (function() {
  function LittleCar(bot) {
    this.bot = bot;
    $.ajaxSetup({
      xhr: function() {
        return new window.XMLHttpRequest({
          mozSystem: true
        });
      }
    });
  }

  LittleCar.prototype.drive = function(code, speed) {
    if (speed == null) {
      speed = 15;
    }
    return $.ajax('http://localhost:8080/' + code + speed.toString(16), {
      type: 'GET',
      dataType: 'html',
      success: (function(_this) {
        return function(data) {
          return _this.announce({
            battery: data
          });
        };
      })(this)
    });
  };

  return LittleCar;

})();

BigCar = (function() {
  function BigCar(bot, pace, address, port) {
    this.bot = bot;
    this.pace = pace != null ? pace : 250;
    this.address = address != null ? address : "192.168.2.3";
    this.port = port != null ? port : 9000;
    this.connecting = false;
    this.connectSocket();
    this.code = 0;
    window.setInterval(((function(_this) {
      return function() {
        return _this.nextCode();
      };
    })(this)), this.pace);
  }

  BigCar.prototype.connectSocket = function() {
    var error;
    if (this.connecting) {
      return;
    }
    try {
      this.socket = navigator.mozTCPSocket.open(this.address, this.port);
    } catch (_error) {
      error = _error;
      if (this.warned) {
        return;
      }
      console.log("cannot open a tcp socket");
      console.log(error);
      this.warned = true;
      return;
    }
    this.connecting = true;
    this.socket.onopen = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    this.socket.onerror = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    this.socket.onclose = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    return this.socket.ondata = (function(_this) {
      return function(event) {
        var level;
        level = (parseInt(event.data.slice(2), 16) - 2655) * 0.20;
        return _this.announce({
          battery: level
        });
      };
    })(this);
  };

  BigCar.prototype.drive = function(code) {
    this.code = code;
  };

  BigCar.prototype.code2command = function(code) {
    var newCode;
    newCode = "05893476"[code - 1];
    if (newCode) {
      return "$" + newCode + "9476$?";
    }
    return "$?";
  };

  BigCar.prototype.steer = function(code) {
    if (code === 5 || code === 7) {
      return "3";
    }
    if (code === 6 || code === 8) {
      return "4";
    }
    return null;
  };

  BigCar.prototype.nextCode = function() {
    var steering;
    if (this.socket && this.socket.readyState === "open") {
      if (this.code > -5) {
        console.log("sending drive " + this.code);
        steering = this.steer(this.code);
        if (steering) {
          this.socket.send(this.code2command(steering));
        }
        this.socket.send(this.code2command(this.code));
        if (steering) {
          this.socket.send(this.code2command(steering));
        }
        if (this.code < 1) {
          return this.code -= 1;
        }
      }
    } else {
      return this.connectSocket();
    }
  };

  return BigCar;

})();

Announcer = (function() {
  function Announcer(name) {
    this.name = name;
    console.log("Tracking " + this.name + " events");
  }

  Announcer.prototype.setBot = function(bot) {
    this.bot = bot;
  };

  Announcer.prototype.announce = function(message) {
    if (this.bot) {
      return this.bot.announce(message);
    }
  };

  return Announcer;

})();

ButtonAnnouncer = (function(_super) {
  __extends(ButtonAnnouncer, _super);

  function ButtonAnnouncer(name, buttons) {
    var action, _fn, _i, _len;
    ButtonAnnouncer.__super__.constructor.call(this, name, bot);
    _fn = (function(_this) {
      return function(action) {
        return $("#" + action + "-button").click(function() {
          return _this.announce({
            button: action
          });
        });
      };
    })(this);
    for (_i = 0, _len = buttons.length; _i < _len; _i++) {
      action = buttons[_i];
      _fn(action);
    }
  }

  return ButtonAnnouncer;

})(Announcer);

CrashAnnouncer = (function(_super) {
  __extends(CrashAnnouncer, _super);

  function CrashAnnouncer(name, magnitude, mininterval) {
    this.magnitude = magnitude != null ? magnitude : 25;
    this.mininterval = mininterval != null ? mininterval : 1000000;
    CrashAnnouncer.__super__.constructor.call(this, name, bot);
    this.motionTimeStamp = 0;
    this.motionVector = {
      x: 0,
      y: 0,
      z: 0
    };
    this.crash_id = window.addEventListener('devicemotion', (function(_this) {
      return function(event) {
        var a, interval, m, v;
        a = event.accelerationIncludingGravity;
        m = _this.motionVector;
        v = Math.pow(a.x - m.x, 2) + Math.pow(a.y - m.y, 2) + Math.pow(a.z - m.z, 2);
        interval = event.timeStamp - _this.motionTimeStamp;
        _this.motionVector = {
          x: a.x,
          y: a.y,
          z: a.z
        };
        if (v > _this.magnitude && interval > _this.mininterval) {
          console.log("motion event magnitude " + v + " after " + (interval / _this.mininterval) + " intervals");
          _this.announce({
            crash: event
          });
          return _this.motionTimeStamp = event.timeStamp;
        }
      };
    })(this));
  }

  return CrashAnnouncer;

})(Announcer);

OrientationAnnouncer = (function(_super) {
  __extends(OrientationAnnouncer, _super);

  function OrientationAnnouncer(name) {
    OrientationAnnouncer.__super__.constructor.call(this, name, bot);
    this.orientation_id = window.addEventListener('deviceorientation', (function(_this) {
      return function(event) {
        return _this.announce({
          orientation: event
        });
      };
    })(this), true);
  }

  return OrientationAnnouncer;

})(Announcer);

LocationAnnouncer = (function(_super) {
  __extends(LocationAnnouncer, _super);

  function LocationAnnouncer(name) {
    LocationAnnouncer.__super__.constructor.call(this, name, bot);
    this.watch_id = navigator.geolocation.watchPosition(((function(_this) {
      return function(location) {
        return _this.announce({
          location: location
        });
      };
    })(this)), (function() {
      return console.log("geolocation error");
    }), {
      enableHighAccuracy: true
    });
  }

  return LocationAnnouncer;

})(Announcer);

TimeAnnouncer = (function(_super) {
  __extends(TimeAnnouncer, _super);

  function TimeAnnouncer(name) {
    TimeAnnouncer.__super__.constructor.call(this, name, bot);
    this.interval_id = window.setInterval(((function(_this) {
      return function() {
        return _this.announce({
          timer: 1
        });
      };
    })(this)), 1000);
  }

  return TimeAnnouncer;

})(Announcer);

CompassAnnouncer = (function(_super) {
  __extends(CompassAnnouncer, _super);

  function CompassAnnouncer(name, offset, factor) {
    this.offset = offset != null ? offset : 0;
    this.factor = factor != null ? factor : 1;
    CompassAnnouncer.__super__.constructor.call(this, name, bot);
    this.orientation_id = window.addEventListener('deviceorientation', (function(_this) {
      return function(event) {
        return _this.announce({
          compass: (360 + _this.offset + _this.factor * event.alpha) % 360
        });
      };
    })(this), true);
  }

  return CompassAnnouncer;

})(Announcer);

RobotTestMachine = (function(_super) {
  __extends(RobotTestMachine, _super);

  function RobotTestMachine(driver) {
    this.driver = driver;
    RobotTestMachine.__super__.constructor.call(this, "ready", ["stop"], (function(_this) {
      return function(oldState, currentState) {
        if (currentState === _this) {
          return _this.driver.drive(0);
        }
      };
    })(this));
    this.limited = this.addChild(new RobotTimeLimit("limiting", [], 600));
    this.sequence = this.limited.addChild(new RobotSequentialState("stepping", ["go"]));
    this.sequence.addForward = false;
    this.limited.addChild(new RobotFlaggingState(this.driver, "storing", "p", ["store"], this.sequence));
    this.limited.addChild(new RobotState("driving", ["drive"], null, (function(_this) {
      return function() {
        return _this.driver.drive(5);
      };
    })(this)));
    this.addChild(new RobotState("resetting", ["reset"], (function(_this) {
      return function() {
        return new RobotTestMachine(_this.driver);
      };
    })(this)));
    this.addChild(new RobotPhotographingState("shooting", ["shoot"], "picture1"));
    this.addChild(new CompassCalibrator("calibrating", ["calibrate"], this.driver));
  }

  return RobotTestMachine;

})(ButtonWatcher);

timer_id = null;

bot = new StateTracker(function(state, event) {
  var eventkey, eventval, html, lastevent;
  console.log("pushed state to " + state.name);
  lastevent = event ? (eventkey = Object.keys(event)[0], eventval = event[eventkey], " " + eventkey + ":" + eventval) : "";
  html = state.ancestor().accordian(state, lastevent);
  clearTimeout(timer_id);
  return timer_id = setTimeout((function(html) {
    return $("#set").html(html).collapsibleset("refresh");
  }), 500, html);
});

$(function() {
  bot.setState(new RobotTestMachine(new BigCar(bot, 200)));
  bot.addAnnouncer(new ButtonAnnouncer("button", ["go", "stop", "store", "reset", "drive", "shoot", "calibrate"]));
  bot.addAnnouncer(new CrashAnnouncer("crash"));
  bot.addAnnouncer(new OrientationAnnouncer("orientation"));
  bot.addAnnouncer(new LocationAnnouncer("location"));
  return bot.addAnnouncer(new TimeAnnouncer("time"));
});
