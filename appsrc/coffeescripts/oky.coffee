# Oky framework
# -------------------------

Oky = Oky or {}

class Oky.Collection extends Backbone.Collection
  getConstructor: -> Object.getPrototypeOf(this).constructor

class Oky.Router extends Backbone.Router
  # default transition is 'prev' to handle back button case
  defaultTransition: 'prev'

  # The transition is stored on the router as in the back button case
  # there is no opportunity to work out the correct transition to use before a
  # route is executed
  transition: false # disable initial transition on app start

  initialize: (options) ->
    @transition = @transition # instance property

    super

    @appView = options.appView if options.appView

  appendView: (view) -> @appView.appendView(view, @transition)

  go: (path, transition, replace = false) ->
    console.warn('Router re-navigating to current route') if path is this.getCurrentRoute()

    # guard against navigation while in transitional state
    # kind of a hack to avoid AppView edge case bugs when user spams input
    if @appView.currentView? and @appView.currentView.ready? and not @appView.currentView.ready
      return # cancel this navigation
    
    if transition
      if typeof transition is 'string'
        @transition = transition
      else
        @transition = 'next'
    else
      @transition = false

    this.navigate(path, trigger: true, replace: replace)

    # reset @transition to handle back button case
    @transition = @defaultTransition if @transition

  back: ->
    history.back()

  getCurrentRoute: ->
    if (location.hash != "")
      location.hash.substring(1)
    else
      location.pathname.substring(1)

class Oky.View extends Backbone.View
  # These properties are duplicated for each instance upon construction (not just prototypically delegated).
  # This includes deep structured objects, such as those used for Oky.Layout and jQuery plugin options.
  @instanceProperties: ['layout']
  @debugEvents: false

  className: 'view'

  constructor: ->
    @className = this.getPrototypesClassNames().join(' ')

    super

    if @constructor.instanceProperties?
      for propertyName in @constructor.instanceProperties
        this[propertyName] = _.cloneDeep(this[propertyName])

  initialize: (options = {}) ->
    # set up event proxy
    if options.proxy?
      @proxy = options.proxy
    else
      @proxy = this

    # debug events
    this.on('all', -> console.debug(arguments)) if Oky.View.debugEvents

  # Traverse prototype chain to collect 'className' properties of all superclasses
  # This allows the CSS classes on a view to reflect its view class hierarchy
  getPrototypesClassNames: (currentObject = Object.getPrototypeOf(this), classNames = []) ->
    classNames.push(currentObject.className) if currentObject.hasOwnProperty('className')
    superObject = currentObject.constructor.__super__
    if superObject? and currentObject isnt Backbone.View
      return this.getPrototypesClassNames(superObject, classNames)
    return classNames

  addClassName: (className) ->
    return
    @classList = [] unless this.hasOwnProperty('classList')
    @classList.push(className)

  delegateEvents: (events) ->
    if !@events
      @events = events

    if !Modernizr.touch
      # convert touch events to mouse events for desktop use
      for key of @events
        if key.indexOf('touchend') == 0
          newKey = key.replace('touchend', 'mouseup')
          oldValue = @events[key]
          @events[newKey] = oldValue
          delete @events[key]
        else if key.indexOf('touchstart') == 0
          newKey = key.replace('touchstart', 'mousedown')
          oldValue = @events[key]
          @events[newKey] = oldValue
          delete @events[key]
    
    super

  close: ->
    @remove()
    @unbind()

# Main application view to which all other views are attached
# Primarily to provide transitions and subview layout
class Oky.AppView extends Oky.View
  className: 'appview'
  activeViews: []
  currentView: null

  # Use CSS3 transform: translate instead of position for transitions.
  # Hardware accelerated on newer mobile browsers.
  transitionTransform: true

  # Use CSS3 transform: translate3d instead of transform for transitions.
  # Hardware accelerated on almost all mobile browsers.
  transitionTransform3d: false

  transitionDuration: 400

  constructor: (options) ->
    _.extend(this, options)
    super

  getSubviews: ->
    subviews = []
    subviews.push(@currentView) if @currentView?
    return subviews

  ###
  Performs the task of initiating the render chain of whole screens of the app,
  appending them to the main DOM, and optionally transitioning them into view.
  ###
  appendView: (@currentView, transition = false) ->
    # actually add the view element to the document. for realsies.
    this.$el.append(@currentView.render().el)

    # layout can be applied once all views are rendered and attached to the DOM
    Oky.Layout.applyLayout(this)

    if @activeViews.length
      oldView = _.last(@activeViews)
      oldView.trigger('view:transitionstart')
      this.transitionToCurrentView(transition)
    else
      @activeViews.push(@currentView)
      @currentView.trigger('view:transitionstart')
      @currentView.trigger('view:transitionend')
      @currentView.trigger('view:live')

  # @private
  closePreviousViews: ->
    # Two things are happening here, firstly removing all but the last of
    # activeViews, leaving only the newest view, and secondly performing cleanup
    # on all removed views ie. those returned by the call to splice().
    _.each(@activeViews.splice(0, @activeViews.length-1), (oldView) ->
      oldView.trigger('view:transitionend')
      clearTimeout(oldView.animationTimer) if oldView.animationTimer
      oldView.close()
    )

  # @private
  transitionToCurrentView: (animation) ->
    # Ideally there shouldn't be any views to close at this point, however this
    # situation may occur if multiple transitions are occuring concurrently.
    this.closePreviousViews()

    # If multiple transitions are occuring concurrently the remaining view in
    # activeViews may require its (in-progress) animation to be cleared.
    _.last(@activeViews, (view) -> view.$el.css('left', 0))

    @activeViews.push(@currentView)
    @currentView.trigger('view:transitionstart')
    @currentView.trigger('view:live')

    if animation
      # The new view is moved it into position to be in its final location at
      # the end of the animation but before it resets to original position.

      # animate transition to new view, then close previous view(s)
      @currentView.animationTimer = this.animateTransitionToView(@currentView, animation, =>
        # Ideally, there should only be one 'new view' and one 'old view', 
        # however this might not be the case if multiple views are pushed concurrently
        this.closePreviousViews()
        # Move back to normal position after animation finishes and resets view 
        # to original position
        @currentView.$el.css('left', 0)
        @currentView.trigger('view:transitionend')
      )
    else
      # no animation, just discard the previous view(s)
      this.closePreviousViews()
      @currentView.trigger('view:transitionend')

  # @private
  animateTransitionToView: (view, animation, afterAnimation) ->
    if @animations.fn[animation]?
      @animations.reset(this)
      # Call the animation function for this animation.
      @animations.fn[animation](this, view)
      # Unfortunately the animation completion callbacks on $.animate don't seem 
      # to be reliable, possibly due to the fact that the underlying transitionEnd 
      # event doesn't always fire, so we have this setTimeout (sadness) instead.
      return setTimeout(=>
        @animations.reset(this)
        # to avoid the appearance of 'jumping back' to start position, inner
        # elements should be moved to final positions in afterAnimation callback.
        afterAnimation()
      , @transitionDuration)
    else
      throw new Error('Invalid animation: ' + animation)

  animations:
    reset: (appView) ->

      # reset transition properties
      this.transition(appView.$el)

      if appView.transitionTransform
        if appView.transitionTransform3d
          translateOrigin = 'translate3d(0, 0, 0)'
        else
          translateOrigin = 'translate(0, 0)'

        appView.$el.css
          'transform': translateOrigin
          '-webkit-transform': translateOrigin
      else
        appView.$el.css
          'position': 'relative'
          'left': 0

    # Set or reset css transition property on view container
    transition: ($container, duration, easing) ->
      # if zero or no duration provided, reset transition properties
      if duration
        transition = "all #{duration} #{easing}"
      else
        transition = 'none'

      $container.css
        'transition': transition
        '-webkit-transition': transition

    fn:
      next: (appView, view) ->
        view.$el.css('left', view.$el.width())

        if appView.transitionTransform
          if appView.transitionTransform3d
            appView.$el.animate('translate3d': -view.$el.width()+'px, 0, 0', appView.transitionDuration, 'ease-in-out')
          else
            appView.$el.animate('translate': -view.$el.width()+'px, 0', appView.transitionDuration, 'ease-in-out')
        else
          appView.$el.animate('left': -view.$el.width()+'px', appView.transitionDuration, 'ease-in-out')

      prev: (appView, view) ->
        view.$el.css('left', - view.$el.width())

        if appView.transitionTransform
          if appView.transitionTransform3d
            appView.$el.animate('translate3d': view.$el.width()+'px, 0, 0', appView.transitionDuration, 'ease-in-out')
          else
            appView.$el.animate('translate': view.$el.width()+'px, 0', appView.transitionDuration, 'ease-in-out')
        else
          appView.$el.animate('left': view.$el.width()+'px', appView.transitionDuration, 'ease-in-out')

# @mixin
# Rather than using this, you should use flexbox
Oky.Layout =
  dimensions: ['height', 'width']

  # Applies fixed dimensions to views to fill space allowed by other views with 
  # fixed size for dimension. 
  # Eg. content view height = screen height - (titlebar height + tabs height)

  # View should provide getSubviews() method.
  # Subviews participating in layout should provide a 'layout' property. 
  # @param view [Object] view object to which layout should be applied, should provide a 'layout' property.
  # @option view layout [Object] options for layout in each dimension (height, width)
  # @option view.layout height [Object] options for layout in vertical dimension
  # @option view.layout height.type [String] 'fixed' or 'fill'
  # @option view.layout height.value [Number] size for fixed dimension
  # @option view.layout width [Object] (same as view.layout.height, but for width)
  # @option view.layout width.type [String] 'fixed' or 'fill'
  # @option view.layout width.value [Number] size for fixed dimension
  #        
  # Either dimension is optional for view.layout.
  applyLayout: (view) ->
    return unless typeof view.getSubviews is 'function'

    subviews = view.getSubviews()

    # ignore subviews without 'layout' property
    layoutSubviews = _.filter(subviews, (subview) -> subview.layout?)

    for dimension in @dimensions
      # sort subviews into 'fill' and 'fixed'
      fillViews = []
      fixedViews = []
      for subview in layoutSubviews
        if subview.layout[dimension]
          fillViews.push(subview)  if subview.layout[dimension].type is 'fill'
          fixedViews.push(subview) if subview.layout[dimension].type is 'fixed'

      # sum fixed-layout subview dimension sizes for this dimension
      fixedTotal = 0
      for fixedView in fixedViews
        # set fixed size if supplied in layout object
        if fixedView.layout[dimension].value?
          fixedViewDimensionSize = fixedView.layout[dimension].value
          fixedView.$el[dimension](fixedViewDimensionSize)
        else
          fixedViewDimensionSize = fixedView.$el[dimension]()

        fixedTotal += fixedViewDimensionSize

      if fillViews.length
        # available fill size is distributed evenly over fillViews
        fillSize = (view.$el[dimension]() - fixedTotal) / fillViews.length

        fillView.$el[dimension](fillSize) for fillView in fillViews

    # subview layout is applied recursively because often
    # child view subview layout depends on layout already being applied to 
    # parent views (for dimension fill layouts at least)
    this.applyLayout(subview) for subview in subviews

