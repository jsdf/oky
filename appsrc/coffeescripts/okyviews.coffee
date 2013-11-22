Handlebars.registerHelper('attr', (context = {}, options) ->
  attributes = []
  attributes.push(attribute + '="' + value + '"') for attribute, value of context
  ' ' + attributes.join(' ')
)

###
Base View for all views which utilise a template
###

class TemplateView extends DHM.View
  template: 'Default'
  className: 'templateview'
  
  initialize: (options) ->
    super
    # if no context is provided, template is rendered using view properties
    @context = @context or this

  getTemplate: -> @template

  getContext: -> @context

  render: ->
    template = JST[this.getTemplate()]

    this.$el.empty()
    this.$el.html(template(this.getContext()))
    return this

###
Generic Views
###

class TableView extends TemplateView
  template: 'Table'
  labelAttribute: 'name'
  layout: height: type: 'fill'
  scrolling: false

  className: 'tableview'
  
  initialize: (options = {}) ->
    super
    this.setCollection(options.collection or new DHM.Collection())

  setCollection: (@collection) ->

  getContext: -> list: this.buildListItems()

  buildListItems: ->
    @collection.map((item) =>
      id: item.cid
      label: this.getItemLabel(item)
    )

  getItemLabel: (item) -> item.get(@labelAttribute)

  events:
    'touchend ul.list > li': 'itemOnTouchend'
    'touchstart ul.list > li': 'itemOnTouchstart'
    'scroll' : 'viewOnScroll'

  itemOnTouchstart: (event) ->
    @scrolling = false
    return

  viewOnScroll: (event) ->
    @scrolling = true
    return

  itemOnTouchend: (event) ->
    selectedItemCid = $(event.currentTarget).data('list-item')
    if !@scrolling
      @proxy.trigger('table:select', @collection.get(selectedItemCid))
    @scrolling = false
    return false


class FilterableTableView extends TableView
  messageNoItems: 'Sorry, no items were found'

  className: 'filterabletableview'
  
  initialize: (options) ->
    super

  setCollection: (@baseCollection) -> this.reset()

  filter: (callback) ->
    @collection = new (@baseCollection.getConstructor())(@baseCollection.filter(callback))

  reset: -> @collection = @baseCollection

  render: ->
    if @collection.length
      super
    else
      this.$el.html(JST['Passthrough'](content: @messageNoItems))
    return this


class FieldView extends TemplateView
  @instanceProperties: ['layout', 'fieldAttributes']

  template: 'Field'
  fieldAttributes:
    type: 'text'
    class: 'field-text'

  className: 'fieldview'
  
  initialize: (options) ->
    super

    defaultFieldAttributes = _.cloneDeep(@fieldAttributes)
    _.extend(this, options)
    console.log(this)
    _.defaults(@fieldAttributes, defaultFieldAttributes)

  setValue: (value) ->
    @fieldAttributes.value = value
    this.$el.find('input').val(value)

  change: (value) ->
    @proxy.trigger('field:change', @name, value)

  events:
    'change input': 'onChange'
    'keyup input': 'onKeyUp'

  onChange: (event) ->
    $field = this.$el.find('input')
    this.change($field.val())
    return false

  onKeyUp: (event) ->
    $field = this.$el.find('input')
    this.change($field.val())
    return false


class ContentView extends TemplateView
  template: 'Content'

  className: 'contentview'
  
  initialize: (options) ->
    super
    @context = content: if options.content? then options.content else 'Content not set'


class MessageView extends ContentView
  template: 'Message'

  className: 'messageview'
  

class FormView extends DHM.View
  className: 'formview'

  subviews: {}

  getSubviews: -> _.values(@subviews)

  render: ->
    this.$el.empty()
    this.$form = $('<form></form>')
    _.each(_.sortBy(@subviews,'weight'), (subview) =>
      this.$form.append(subview.view.render().el)
    )
    this.$el.append(this.$form)
    return this


class TitleBarView extends TemplateView
  template: 'TitleBar'
  title: 'TitleBarView'
  next: 'Next'
  prev: 'Back'
  layout: height: type: 'fixed', value: 44

  className: 'titlebarview'

  initialize: (options = {}) ->
    super
    _.extend(this, options)

  render: ->
    super
    this.$el.find('.button-next, .button-prev').addTouchHandle()
    return this

  events:
    'touchend .button-next': 'nextOnTap'
    'touchend .button-prev': 'prevOnTap'

  nextOnTap: ->
    @proxy.trigger('nav:next')
    return false

  prevOnTap: ->
    @proxy.trigger('nav:prev')
    return false


class TabBarView extends TemplateView
  template: 'TabBar'
  layout: height: type: 'fixed'

  className: 'tabbarview'

  ###
  @tabs is an array of tab objects.
  Each tab object should have the following properties:
    name: the name passed to the tab event handler
    label: the text label shown on the tab
    icon: the name of the icon shown on the tab
  ###
  tabs: []
  fixedHeight: 50

  initialize: ->
    super

  render: ->
    super
    this.$el.height(@fixedHeight)
    return this

  findTab: (tabName) -> _.find(@tabs, name: tabName)

  events:
    'touchend .tab-item': 'tabOnTap'

  tabOnTap: (event) ->
    this.trigger('tab:change', $(event.currentTarget).data('tab-name'))
    return false


###
Base class for any view which has a titlebar and next/prev controls
###
class NavigableView extends DHM.View
  titleBarView: null
  contentView: null
  ###
  The @ready property is used to track whether a view is in a state in which input
  is allowed. The main reason it might not be allowed is during a transition
  between views, to prevent multiple taps causing multiple transitions to occur.
  ###
  ready: true
  ###
  The @live property is used to track whether a view has been appended to the
  main document (ie. when view:live is triggered on it). 
  ###
  live: true

  className: 'navigableview'
  
  initialize: (options) ->
    super

    if not @titleBarView? then @titleBarView = new TitleBarView(proxy: this)
    if not @contentView? then @contentView = new DHM.View()

    # contentViews generally use 'fill height' layout
    _.defaults(@contentView, layout: height: type: 'fill')
    
    this.on('view:live', (view) => @live = true)
    this.on('view:transitionstart', (view) => @ready = false)
    this.on('view:transitionend', (view) => @ready = true)

    if @options.router? and @options.routerNavigable
      this.on('nav:prev', => @options.router.back() if @ready)

  getSubviews: -> [@titleBarView, @contentView]

  render: ->
    @live = false
    this.$el.empty()
    this.$el.append(@titleBarView.render().el)
    this.$el.append(@contentView.render().el)
    @contentView.$el.addClass('contentview')
    return this
