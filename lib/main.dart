import 'dart:async';

import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:quiver/async.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Countdown Controller',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: MyHomePage(title: 'Countdown Controller'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final database = FirebaseDatabase.instance.reference().child('countdown');

  int _countdownTime = 1;
  bool _state = false;
  int _secondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
  CountdownTimer countdownTimer;
  String _countdownText = "0:00";

  void _startCountdown() {
    _state = true;
    // Work out in milliseconds how long left
    var now = DateTime.now().millisecondsSinceEpoch;
    _secondsSinceEpoch = DateTime.now().add(Duration(minutes: _countdownTime)).millisecondsSinceEpoch;
    var diff =  _secondsSinceEpoch - now;
    updateCountdown();
    _doCountdown(_secondsSinceEpoch);
  }

  void _stopCountdown() {
    _state = false;
    updateCountdown();
    _countdownText = "0:00";
    countdownTimer.cancel();
  }

  void _changeCountdown(_newTime) {
    _countdownTime = _newTime;
    _secondsSinceEpoch = DateTime.now().toUtc().add(Duration(minutes: _newTime)).millisecondsSinceEpoch;
    updateCountdown();
  }

  void updateCountdown() {
    database.update({
        'start': _state,
        'time': _countdownTime,
        'timestamp': _secondsSinceEpoch
      });
  }

  void _doCountdown(var countdownMilliseconds) {
    _state = true;
    updateCountdown();
    // Start Countdown
    countdownTimer = new CountdownTimer(
      new Duration(milliseconds: countdownMilliseconds),
      new Duration(seconds: 1),
    );

    var sub = countdownTimer.listen(null);

    sub.onData((duration) {
      setState(() {

        int minutes = duration.remaining.inMinutes;
        String seconds = (duration.remaining.inSeconds % 60).toString().padLeft(2, '0');
        _countdownText = "$minutes:$seconds"; 
      });

      sub.onDone(() {
        showAlertDialog(context);
        _state = false;
        updateCountdown();
        sub.cancel();
      });
    }); 
  }

  // Alert user that countdown has finished
  showAlertDialog(BuildContext context) {
    Widget okButton = FlatButton(
      child: Text("OK"),
      onPressed: () { Navigator.of(context).pop();},
    );
    AlertDialog alert = AlertDialog(
      title: Text("Demo finished"),
      content: Text("Please get the next team ready for demoing!"),
      actions: [
        okButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StreamBuilder(
              stream: database.onValue,
              builder: (context, snap) {
                if (snap.hasData && !snap.hasError && snap.data.snapshot.value != null) {
                  if (_state == false) {
                    Map data = snap.data.snapshot.value;
                    _countdownTime = data['time'];
                    _countdownText = "$_countdownTime:00";
                    return 
                      Column (
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "$_countdownText",
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: new TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 100),
                          ),
                        ]
                      );
                  } else if (_state == true) {
                    return 
                      Text(
                        "$_countdownText",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: new TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 100),
                      );
                  }
                }
                else
                  return Text("Error: No Time");
              },
            ),
            SizedBox(height: 80),
            new Text(
                "Set Minutes:",
                style: TextStyle(fontSize: 25),
            ),
            new NumberPicker.integer(
                initialValue: _countdownTime,
                minValue: 1,
                maxValue: 9,
                onChanged: (newValue) => setState(() => _changeCountdown(newValue))),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  new RaisedButton.icon(
                    textColor: Colors.white,
                    color: Colors.green,
                    onPressed: _startCountdown,
                    label: Text("Start"),
                    icon: Icon(Icons.play_arrow),
                    shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(20.0)),
                  ),
                  new RaisedButton.icon(
                    textColor: Colors.white,
                    color: Colors.red,
                    onPressed: _stopCountdown,
                    label: Text("Stop"),
                    icon: Icon(Icons.stop),
                    shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(20.0)),
                  ),
              ]),
            StreamBuilder(
              stream: database.onValue,
              builder: (context, snap) {
                if (snap.hasData && !snap.hasError && snap.data.snapshot.value != null) {
                  
                  Map data = snap.data.snapshot.value;
                  _state = data['start'];
                  _countdownTime = data['time'];
                  _secondsSinceEpoch = data['timestamp'];

                  // Check if another device has triggered the countdown
                  if (_state == true && countdownTimer.isRunning) {
                    var now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    var diff = _secondsSinceEpoch - now;
                    _doCountdown(diff);
                  }

                  return Padding(
                    padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
                    child: Column (
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        RaisedButton.icon(
                          textColor: Colors.white,
                          color: Colors.orange,
                          onPressed: () => _doCountdown(_secondsSinceEpoch),
                          label: Text("Remote Override"),
                          icon: Icon(Icons.publish),
                          shape: new RoundedRectangleBorder(borderRadius: new BorderRadius.circular(20.0)),),
                        Text("Firebase Database", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        Text("start: $_state", style: TextStyle(fontSize: 16)),
                        Text("time: $_countdownTime", style: TextStyle(fontSize: 16)),
                        Text("timestamp: $_secondsSinceEpoch", style: TextStyle(fontSize: 16))
                    ])
                  );
                }
                else
                  return Text("No data from Firebase RTDB");
                },
            ),
          ],
        ),
      ),
    );
  }
}

