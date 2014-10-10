// get a reference to the install button
var button = document.getElementById('install-btn');

button.addEventListener('click', function() {
  socket = navigator.mozTCPSocket.open("localhost", 8080);
  command = String.fromCharCode(1*16 + 7);
  socket.send(command);
  setTimeout(function(){
    var command = String.fromCharCode(0);
    socket.send(command);
  }, 2000);
})
