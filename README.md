# Build Spork

<img src="https://raw.githubusercontent.com/wiki/musictheory/BuildSpork/screenshot.png" width="789" height="286">

Build Spork provides a graphical user interface to build tools such as [jake](http://jakejs.com) or [rake](https://github.com/ruby/rake).

It also broadcasts all events via [NSDistributedNotificationCenter](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDistributedNotificationCenter_Class/index.html), enabling other processes to listen and act accordingly.

### Why?

[Sublime Text](http://www.sublimetext.com) includes support for build systems.  However, the support is very basic (projects have one designated build action, making it hard to support multiple targets with multiple build configurations).  Over time, the [musictheory.net](http://www.musictheory.net) build script outgrew this limited support.

More importantly, [Sublime Text](http://www.sublimetext.com) lacks real support for continuously running build systems.  Ideally, we want our build script running at all times, watching files, and starting builds.  When issues occur, a Sublime Text output panel appears.  When all issues are fixed, the output panel disappears.

### Design

<img src="https://raw.githubusercontent.com/wiki/musictheory/BuildSpork/window.png" width="526" height="82">

The Build Spork window comprises four sections:

**Projects** - a list of projects.  You can add and remove projects via the Projects window.

**Targets** - a list of targets and a build button.  A target is not ran until the Build button is pressed.

**Actions** - additional button.  An action is ran immediately when pressed.


### Configuration

A project is configured via the `spork.json` file at the base directory of the project.  Look at the `TestProject` example for a complete list of options.

### Output

By default, each line your script outputs is treated as a `message` event.  It will show up in the output log, and be broadcasted as type `message`.

If a line starts with a file path and line number, it is interpretted as an `issue` event.  For example:

    Source/Foo.js:45 Unknown variable _foo
    
would broadcast the following event:

    { "type": "issue", "path": "Source/Foo.js", "line": "45", "issue": "Unknown variable _foo" }

and be added to the output log as a clickable link to line 45 in Foo.js.

If a line starts with `[spork]`, Build Spork instead interprets it as a special event:

`[spork] reset` - Resets the build log

`[spork] mark` - Appends a horizontal line rule to the log 

`[spork] info message_content` - Appends an "info" message, which appears in faded color.

`[spork] init` - Informs Build Spork that your script is long-running and may contain multiple start/stop events.  If your script
does not output an `init` event in the first line, Build Spork assumes your script runs for a single build.

`[spork] start` - Informs Build Spork that a build is starting.  This event is automatically broadcasted for single-build scripts.

`[spork] stop` - Informs Build Spork that a build stopped.  This event is automatically broadcasted for single-build scripts.

Note: When a script is ran by Build Spork, the `net_musictheory_spork` environment variable is set to `1`.  When this variable is not set, you may wish to suppress `[spork]` messages.

### Notifications

All events are broadcasted via [NSDistributedNotificationCenter](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDistributedNotificationCenter_Class/index.html)
with a notification name of `net.musictheory.spork.event`.

When the user clicks on a file issue, Build Spork emits a `net.musictheory.spork.open` notification.

Look at the example Sublime Text plug-in to see how to integrate these notifications with an editor.
