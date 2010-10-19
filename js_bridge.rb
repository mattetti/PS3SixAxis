framework 'Cocoa'
framework 'WebKit'

class Cat
  attr_accessor :name, :age
  def initialize(name = nil, age=nil)
    @name = name || 'kitty'
    @age  = age  || 42
  end
  
  # Make all the Cat's methods available from JS
  def self.isSelectorExcludedFromWebScript(sel); false end
end

class Browser
  
  attr_accessor :view, :js_engine
  
  def initialize
    @kitty  = Cat.new
    @view   = WebView.alloc.initWithFrame([0, 0, 520, 520])
    @window = NSWindow.alloc.initWithContentRect([200, 200, 520, 520],
                                                styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask, 
                                                backing:NSBackingStoreBuffered, 
                                                defer:false)

    @window.contentView = view
    # Use the screen stylesheet, rather than the print one.
    view.mediaStyle = 'screen'
    view.customUserAgent = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_2; en-us) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10'
    # Make sure we don't save any of the prefs that we change.
    view.preferences.autosaves = false
    # Set some useful options.
    view.preferences.shouldPrintBackgrounds = true
    view.preferences.javaScriptCanOpenWindowsAutomatically = false
    view.preferences.allowsAnimatedImages = false
    # Make sure we don't get a scroll bar.
    view.mainFrame.frameView.allowsScrolling = false
    view.frameLoadDelegate = self
  end

  def fetch
    page_url = NSURL.URLWithString('http://jquery.com')
    view.mainFrame.loadRequest(NSURLRequest.requestWithURL(page_url))
    puts "fetching"
  end
  
  def webView(view, didFinishLoadForFrame:frame)
    @window.display
    @window.orderFrontRegardless
    @js_engine = view.windowScriptObject # windowScriptObject
    @js_engine.setValue(@kitty, forKey: "animal")
    # JIT the method, no colon at the end of the method since the selector doesn't
    # take arguments.
    @kitty.respondsToSelector("age")
    puts "js bridge test: "
    # trigger JS from Ruby
    @js_engine.evaluateWebScript("$('body').text('phase 1');")
    # Evaluate JS from Ruby via the DOM
    puts @js_engine.evaluateWebScript('animal.age()')
    # Execute Ruby code from the DOM
    @js_engine.evaluateWebScript("$('body').text('phase 2 ' + animal.age())")
  end
  
end

Browser.new.fetch
NSRunLoop.currentRunLoop.runUntilDate(NSDate.distantFuture)