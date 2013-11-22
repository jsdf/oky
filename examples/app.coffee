Oky.View.debugEvents = true

class HomeView extends Oky.Views.NavigableView
  className: 'homeview'
  content:  'Welcome to Oky!!! :)<br>'
  
  initialize: (options) ->
    @titleBarView = new Oky.Views.TitleBarView
      proxy: this
      title: 'Home'
      prev: false
      next: 'Next'
    @contentView = new Oky.Views.ContentView
      proxy: this
      content: @content

    this.on('nav:next', => @options.router.go('tableview', true) if @ready)

    super

class TableViewDemoView extends Oky.Views.NavigableView
  className: 'tableviewdemoview'
  
  initialize: (options) ->
    @titleBarView = new Oky.Views.TitleBarView
      proxy: this
      title: 'TableView'
      prev: 'Back'
      next: false
    @contentView = new Oky.Views.TableView
      proxy: this
      collection: new Oky.Collection [
        {name: 'first'}
        {name: 'second'}
        {name: 'third'}
        {name: 'fourth'}
      ]

    super

###
In this app the router acts like a sort of top level controller.
This involves constructing top level views and directing 'app' object 
to append views to the app container.
###

class AppRouter extends Oky.Router
  routes: 
  # 'identfier': 'callback'
    'home': 'home'
    'tableview': 'tableview'
  initialize: (@options) ->
    super

    @appView = new Oky.AppView _.extend(
      router: this
      el: app.$appContainer
    , app.config.appView)

  home: -> this.appendView new HomeView
    router: this
    routerNavigable: true

  tableview: -> this.appendView new TableViewDemoView
    router: this
    routerNavigable: true

app =
  initialize: ->
    @config = 
      transitionTransform: true
      transitionTransform3d: true
      transitionDuration: 350

    # cordova initialisation event
    document.addEventListener('deviceready', =>
      @deviceReady = true
      this.startApp()
    , false)

    # in a non-cordova environment
    if (location.protocol != "file:")
      @deviceReady = true
      this.startApp()

  startApp: ->
    # await cordova ready event 
    return unless @deviceReady

    # the main AppView is assigned to this element
    # all DOM structure is created by views
    this.$appContainer = $('#app-container')

    @router = new AppRouter(app: this)

    # required before backbone router can be used
    Backbone.history.start()

    # start
    @router.go('home')

