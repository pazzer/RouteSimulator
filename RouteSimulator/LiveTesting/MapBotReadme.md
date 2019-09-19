#  <#Title#>

### Adding Waypoints
    
    <dict>
        <key>data</key>
        <dict>
            <key>zones</key>
            <string>49,18,22,47</string>
            <key>connected</key>
            <true/>
        </dict>
        <key>operation</key>
        <string>ADD_WAYPOINTS_TO_ZONES</string>
    </dict>

### Deleting Waypoints

    <dict>
        <key>data</key>
        <string>B</string>
        <key>operation</key>
        <string>DELETE_WAYPOINT</string>
    </dict>
    
### Deleting Arrows

    <dict>
        <key>data</key>
        <string>F</string>
        <key>operation</key>
        <string>DELETE_ARROW</string>
    </dict>
    
### Setting Next

    <dict>
        <key>data</key>
        <string>A→F</string>
        <key>operation</key>
        <string>SET_NEXT</string>
    </dict>
    
### Selecting Waypoints

    <dict>
        <key>data</key>
        <string>*</string>
        <key>operation</key>
        <string>SELECT_WAYPOINT</string>
    </dict>

### Validate Next

    <dict>
        <key>data</key>
        <string>D→*</string>
        <key>operation</key>
        <string>VALIDATE_ROUTE_NEXT</string>
    </dict>

### Validate Arrow Position

    <dict>
        <key>data</key>
        <string>F</string>
        <key>operation</key>
        <string>VALIDATE_ARROW_POSITION</string>
    </dict>
    
    
### Deleted Waypoints

    <dict>
        <key></key>
        <string></string>
        <key>operation</key>
        <string>DELETED_WAYPOINTS</string>
    </dict>
    

