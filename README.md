# Route Simulator
 
RouteSimulator is a sample project that was created to assist with the development of another app - *QuickRoute* - that has since been released on the App Store. Specifically, *RouteSimulator* was used to refine and demonstrate a testing method - dubbed *bot-testing* - that could supplement the testing apparatus provided by Xcode.
 
Like Xcode's User-Interface Testing, bot-testing is designed to allow the developer to simulate user interaction with an app, and then establish whether these interactions have had the intended consequences. Unlike Xcode's native testing suite however, this approach allows the developr to probe the state of the underlying model in response to user activity, rather than just the state of user interface elements.
 
## Bot-Testing Guide
Bot-testing works by allowing the developer to specify a series instructions each of which corresponds to either a user **action** (e.g. a tap on a particular button), or the execution of particular **test**. The bot - with the help of its data-source - converts these instructions into blocks of code, which are in turn executed one-at-a-time on consecutive run-loop iterations. The results of any tests are reported to the bot's delegate, which in turn displays them on the test dashboard.
 
### Definining Actions and Tests
A single bot-test test is housed within a single .plist file, and consists of any number of actions and tests - collectively know as the test's *operations*. In the example below, the test '*Basic Addition*' simulates the user tapping the *add* button after moving the crosshairs to a specific location on the screen. This is then followed by a test which validates that the number of waypoints within the model is now one. Note that in addition to action blocks and test blocks, the user can insert simple strings to group a set of related operations; in this example the first two actions are grouped together under the title *'Adding A'*, and the single test is grouped under the title *'One Simple Test'*.
 
 ```
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
     <key>name</key>
     <string>Basic Addition</string>
     <key>operations</key>
     <array>
         <string>Adding A</string>
         <dict>
             <key>data</key>
             <integer>49</integer>
             <key>name</key>
             <string>MOVE_CROSSHAIRS_TO_ZONE</string>
         </dict>
         <dict>
             <key>name</key>
             <string>TAP_ADD</string>
         </dict>
         <string>One Simple Test</string>
         <dict>
             <key>data</key>
             <integer>1</integer>
             <key>name</key>
             <string>COUNT_WAYPOINTS</string>
         </dict>
     </array>
 </dict>
 </plist>
 ```
  
 ### Converting Action and Test Operations to Code
 
When a test is loaded from its plist file, and handed to an instance of ``UIBot`` for execution, the bot asks its data-source to provide executable code capable of carrying out the instructions specfied by each of the test's operations. The example below shows how the ``RouteViewController`` in this project converts the two action operations described above.
 
 ```swift
 
 // RouteViewController.swift
 
 func uiBot(_ uiBot: UIBot, blockForOperationNamed operationName: String, operationData: Any) ->  (() -> Void) {
     switch operationName {
         
     // Editing
     case "TAP_ADD":
         return {
             self.userTappedAdd(self)
         }
 
     case "MOVE_CROSSHAIRS_TO_ZONE":
         return {
             let pt = self.center(of: operationData as! Int)
             self.move(self.crosshairs, to: pt)
         }
 
     default:
         fatalError("\(operationName) not recognised")
     }
 }
 ```
Tests operations are handled in much the same way, but rather than returning a block of code, the function corresponding to a particular test is called, and returns the result of the test (pass or fail), and an accompanying message. The code below corresponds to the test requested by the operation titled `COUNT_WAYPOINTS`.

 ```
 func countWaypoints(expectedWaypoints: Int) -> (Bool, String) {
     let pass: Bool
     let msg: String
     let actualWaypoints = route.numbeOfWaypoints
     let actualCircles = graphicsView.graphics.filter { $0 is Circle }.count
     if actualWaypoints == expectedWaypoints {
         if actualCircles == actualWaypoints {
             pass = true
             msg = "Number of waypoints is \(expectedWaypoints)"
         } else {
             pass = false
             msg = "Number of waypoints is as expected \(expectedWaypoints), but number of circles on the graphicsView is not \(actualCircles)"
         }
     } else {
         pass = false
         msg = "Number of waypoints is \(actualWaypoints), not \(expectedWaypoints)"
     }
     return (pass, msg)
 }
 ```
 
 
### Working through The Tests
Once you've written your tests and completed the relevant data-source methods, you're now in a position to run the tests. Here's how to do it:
 
 1. Create and array of ``UIBotSequence`` objects to store your tests:
     ```
     lazy var testSequences: [UIBotSequence] = {
         var sequences = [UIBotSequence]()
         ["TestOne", "TestTwo"].forEach { (number) in
             if let url = Bundle.main.url(forResource: "Test\(number)", withExtension: "plist") {
                 sequences.append(UIBotSequence(from: url))
             }
         }
         return sequences
     }()
     ```
 
 2. Insert the view stored in ``BotTestsDashboardView`` into your view hierarchy, and set the controller that manages this view (``BotTestsDashboardViewController``) as the ``delegate`` of your ``UIBot`` instance.
 
 3. Set the ``dataSource`` of the ``UIBot`` to the relevant object.
 
 4. Finally, pass the the array  of test sequences to the bot:
     ```
     uiBot.set(sequences: testSequences)
     ```
 
 
You can now use the button's provided on the dashboard-view to work through your tests one operation at a time, one section at a time, or one test at a time. Test results are reported to the dashboard view-controller, which in turn updates the dashboard view.
 
  
## What's Next?
 
Although this testing approach is only going to be useful in a limited number of projects, it would be worth taking a bit of time to implement the following two improvements:
 
 1. **Allow Testing en-masse**.
 As it stands you can't ask the bot to execute all of tests in one fell swoop; if you have 10 tests to run, then you have to hit the 'run test' button ten times to work through them all. This is frustrating, even if there are only a small number of tests, therefore there should be a way of requesting all of the tests to run with just a single cue.
 
 2. **Ditch the Dashboard**.
 Currently the dashboard view is indispensible to the testing process: without installing it, you can't really run the tests. This means (i) you have add code to your project to insert and remove the dashboard, and (ii) it assumes that your app's view hierarchy can accomodate the insertion of this view. This is far from ideal, so the dashboard should be made optional, and when not present the results of the tests should be diverted to a log file.
