#  Operations for UIBot Sequences

## Primitive Operations

### Tapping 

    <dict>
        <key>name</key>
        <string>TAP_ADD</string>
    </dict>
    
    <dict>
        <key>name</key>
        <string>TAP_REMOVE</string>
    </dict>
    
    <dict>
        <key>name</key>
        <string>TAP_UNDO</string>
    </dict>
    
    <dict>
        <key>name</key>
        <string>TAP_REDO</string>
    </dict>
    
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>TAP_WAYPOINT</string>
    </dict>   
    
    <dict>
        <key>name</key>
        <string>TAP_EMPTY_ZONE</string>
    </dict>
    
### Positioning the Crosshairs
    
    <dict>
        <key>data</key>
        <string>E</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_ARROW</string>
    </dict>
    
    <dict>
        <key>data</key>
        <string>E</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_WAYPOINT</string>
    </dict>

    <dict>
        <key>data</key>
        <integer>74</integer>
        <key>name</key>
        <string>MOVE_CROSSHAIRS_TO_ZONE</string>
    </dict>
    

## Combining *Primitive* Operations
    
### Adding a Standalone Waypoint

    <string>Adding A</string>
    <dict>
        <key>name</key>
        <string>TAP_EMPTY_ZONE</string>
    </dict>
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
    
### Extending

    <string>Extending from A to New</string>
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>TAP_WAYPOINT</string>
    </dict>
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
    

### Removing a Waypoint

    <string>Removing A</string>
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_WAYPOINT</string>
    </dict>
    <dict>
        <key>name</key>
        <string>TAP_REMOVE</string>
    </dict>
    
### Setting Next

    <string>Setting A → B</string>
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>TAP_WAYPOINT</string>
    </dict>
    <dict>
        <key>data</key>
        <string>B</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_WAYPOINT</string>
    </dict>
    <dict>
        <key>name</key>
        <string>TAP_ADD</string>
    </dict>
    
### Inserting

    <string>Inserting C on arrow A → B</string>
    <dict>
        <key>name</key>
        <string>TAP_EMPTY_ZONE</string>
    </dict>
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_ARROW</string>
    </dict>
    <dict>
        <key>name</key>
        <string>TAP_ADD</string>
    </dict>

### Removing a Connection

    <string>Delete Arrow From A</string>
    <dict>
        <key>data</key>
        <string>A</string>
        <key>name</key>
        <string>SET_CROSSHAIRS_ON_ARROW</string>
    </dict>
    <dict>
        <key>name</key>
        <string>TAP_REMOVE</string>
    </dict>

# Tests

    <dict>
        <key>data</key>
        <integer>2</integer>
        <key>name</key>
        <string>COUNT_WAYPOINTS</string>
    </dict>
    
    <dict>
        <key>data</key>
        <integer>2</integer>
        <key>name</key>
        <string>COUNT_ARROWS</string>
    </dict>
    
    <dict>
        <key>data</key>
        <string>*</string>
        <key>name</key>
        <string>VALIDATE_SELECTION</string>
    </dict>
    
    <dict>
        <key>data</key>
        <string>E→F</string>
        <key>name</key>
        <string>VALIDATE_ROUTE_NEXT</string>
    </dict>
    
    <dict>
        <key>data</key>
        <string>C</string>
        <key>name</key>
        <string>VALIDATE_ARROW_LOCATION</string>
    </dict>

# New Sequence

    <dict>
        <key>name</key>
        <string>?????????</string>
        <key>operations</key>
        <array>
            <!-- OPERATIONS HERE -->
        </array>
    </dict>
