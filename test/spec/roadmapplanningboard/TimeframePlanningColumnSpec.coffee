Ext = window.Ext4 || window.Ext

Ext.require [
  'Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper'
  'Rally.apps.roadmapplanningboard.TimeframePlanningColumn'
  'Rally.apps.roadmapplanningboard.util.TimeframePlanStoreWrapper'
]

describe 'Rally.apps.roadmapplanningboard.TimeframePlanningColumn', ->

  helpers
    createColumn: (config) ->
      @column = Ext.create 'Rally.apps.roadmapplanningboard.TimeframePlanningColumn',
        Ext.merge {},
          contentCell: 'testDiv'
          headerCell: 'testDiv'
          displayValue: 'My column'
          headerTemplate: Ext.create 'Ext.XTemplate'
          timeframeRecord: @timeframeRecord
          store: @featureStoreFixture
          planRecord: @planRecord,
          timeframePlanStoreWrapper: @createTimeframePlanWrapper()
          ownerCardboard:
            showTheme: true
          editPermissions:
            capacityRanges: true
            theme: true
            timeframeDates: true
            deletePlan: true
          columnHeaderConfig:
            editable: true
            record: @timeframeRecord
            fieldToDisplay: 'name'
          renderTo: 'testDiv'
          typeNames:
            child:
              name: 'Feature'
          listeners:
            deleteplan: => @deletePlanStub()
            daterangechange: => @dateRangeChangeStub()
        , config

    createPlanRecord: (config) ->
      @planRecord = Ext.create Rally.apps.roadmapplanningboard.AppModelFactory.getPlanModel(),
        _.extend
          id: 'Foo',
          name: 'Q1',
          theme: 'Take over the world!'
          lowCapacity: 0
          highCapacity: 0
          features: []
        , config

    createTimeframeRecord: (config) ->
      @timeframeRecord = Ext.create Rally.apps.roadmapplanningboard.AppModelFactory.getTimeframeModel(),
        _.extend
          name: 'Q1'
          startDate: new Date('04/01/2013')
          endDate: new Date('06/30/2013')
        , config

    createTimeframePlanWrapper: ->
      Ext.create 'Rally.apps.roadmapplanningboard.util.TimeframePlanStoreWrapper',
        timeframeStore: Deft.Injector.resolve 'timeframeStore'
        planStore: Deft.Injector.resolve 'planStore'

    clickDeleteButton: ->
      @column.deletePlanButton.fireEvent 'click', @column.deletePlanButton
      @confirmDialog = Ext.ComponentQuery.query('rallyconfirmdialog')[0]

  beforeEach ->
    Rally.test.apps.roadmapplanningboard.helper.TestDependencyHelper.loadDependencies()
    @featureStoreFixture = Deft.Injector.resolve 'featureStore'
    @deletePlanStub = @stub()
    @dateRangeChangeStub = @stub()

  afterEach ->
    Deft.Injector.reset()
    @column?.destroy()

  describe 'timeframe column', ->
    beforeEach ->
      @createTimeframeRecord()
      @createPlanRecord
        lowCapacity: 22
        highCapacity: 42

    afterEach ->
      @column?.destroy()

    it 'should have a timeframe added to the header template', ->
      @createColumn()
      headerTplData = @column.getDateHeaderTplData()

      expect(headerTplData['formattedDate']).toEqual 'Apr 1 - Jun 30'

    it 'should render a thermometer in the header template (unfiltered data)', ->
      @createColumn()
      @column.isMatchingRecord = ->
        true

      @column.refresh()

      headerTplData = @column.getHeaderTplData()

      expect(headerTplData['progressBarHtml']).toContain '74 of 42'

    it 'should render a thermometer in the header template (filtered data)', ->
      @createColumn()
      @column.isMatchingRecord = (record) ->
        record.data.Name.indexOf('Android') > -1 || record.data.Name.indexOf('iOS') > -1

      @column.refresh()

      headerTplData = @column.getHeaderTplData()

      expect(headerTplData['progressBarHtml']).toContain '9 of 42'

    it 'should handle empty values as spaces', ->
      @createTimeframeRecord
        startDate: null
        endDate: null
      @createPlanRecord
        lowCapacity: 0
        highCapacity: 0

      @createColumn()

      @column.refresh()

      headerTplData = @column.getHeaderTplData()

      expect(headerTplData['formattedStartDate']).toEqual(undefined)
      expect(headerTplData['formattedEndDate']).toEqual(undefined)
      expect(headerTplData['formattedPercent']).toEqual("0%")
      expect(headerTplData['progressBarHtml']).toBeTruthy()

  describe '#getStoreFilter', ->
    beforeEach ->
      @createTimeframeRecord()

    afterEach ->
      @column.destroy()

    it 'should return a store filter with a null id if there are no features', ->
      @createPlanRecord()
      @createColumn()

      expect(this.column.getStoreFilter().toString()).toBe '(ObjectID = null)'

  describe 'progress bar', ->
    beforeEach ->
      @createTimeframeRecord()
      @createPlanRecord()

    afterEach ->
      @column.destroy()

    describe 'with no capacity', ->
      it 'should display a popover when clicked if editing is allowed', ->
        @createColumn()
        expect(!!@column.popover).toBe false
        @click(this.column.getColumnHeader().getEl().down('.add-capacity span')).then =>
          expect(!!@column.popover).toBe true

      it 'should not enable the planned capacity tooltip when destroying the capacity popover', ->
        @createColumn()
        expect(!!@column.popover).toBe false
        expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true
        @click(this.column.getColumnHeader().getEl().down('.add-capacity span')).then =>
          expect(!!@column.popover).toBe true
          expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true
          @column.popover.destroy()
          expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true

      it 'should not display a set capacity button if editing is not allowed', ->
        @createColumn
          editPermissions:
            capacityRanges: false

        expect(Ext.query('.add-capacity span')).toEqual []

      it 'should disable the planned capacity tooltip on mouseover', ->
        @createColumn()
        expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true
        expect(@column.plannedCapacityRangeTooltip.isVisible()).toBe false

    describe 'with capacity', ->
      beforeEach ->
        @planRecord.set('highCapacity', 10)

      it 'should display a popover when clicked if editing is allowed', ->
        @createColumn()
        expect(!!@column.popover).toBe false
        @click(this.column.getColumnHeader().getEl().down('.progress-bar-container')).then =>
          expect(!!@column.popover).toBe true

      it 'should disable the planned capacity tooltip when clicking the progress bar', ->
        @createColumn()
        expect(!!@column.popover).toBe false
        expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe false
        @click(this.column.getColumnHeader().getEl().down('.progress-bar-container')).then =>
          expect(!!@column.popover).toBe true
          expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true

      it 'should enable the planned capacity tooltip when destroying the capacity popover', ->
        @createColumn()
        expect(!!@column.popover).toBe false
        expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe false
        @click(this.column.getColumnHeader().getEl().down('.progress-bar-container')).then =>
          expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe true
          @column.popover.destroy()
          expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe false

      it 'should not display a popover when clicked if editing is not allowed', ->
        @createColumn
          editPermissions:
            capacityRanges: false

        expect(@column.popover).toBeUndefined()
        @click(this.column.getColumnHeader().getEl().down('.progress-bar-container')).then =>
          expect(!!@column.popover).toBe false

      it 'should show the planned capacity tooltip on mouseover', ->
        @createColumn()
        expect(@column.plannedCapacityRangeTooltip.isDisabled()).toBe false
        expect(@column.plannedCapacityRangeTooltip.isVisible()).toBe false
        @mouseOver(id: @column.progressBar.getId(), {x: 10, y: -5}).then =>
          validate = ->
            expect(@column.plannedCapacityRangeTooltip.isVisible()).toBe true
          setTimeout(validate, 1000)

  describe 'theme header', ->
    beforeEach ->
      @createTimeframeRecord()
      @createPlanRecord()

    afterEach ->
      @column.destroy()

    it 'should render a single theme header', ->
      @createColumn()
      expect(@column.getColumnHeader().query('roadmapthemeheader').length).toBe 1

    it 'should have an editable theme header', ->
      @createColumn()
      theme = @column.getColumnHeader().query('roadmapthemeheader')[0]
      if !Ext.isGecko
        @click(theme.getEl()).then =>
          expect(!!theme.getEl().down('textarea')).toBe true

    it 'should have an uneditable theme header', ->
      @createColumn
        editPermissions:
          theme: false
      theme = @column.getColumnHeader().query('roadmapthemeheader')[0]
      @click(theme.getEl()).then =>
        expect(!!theme.getEl().down('textarea')).toBe false

  describe 'title header', ->
    beforeEach ->
      @createPlanRecord()
      @createTimeframeRecord()

    afterEach ->
      @column.destroy()

    it 'should have an editable title', ->
      @createColumn()

      title = @column.getHeaderTitle().down().getEl()

      @click(title).then =>
        expect(!!title.down('input')).toBe true

    it 'should have an uneditable title', ->
      @createColumn
        columnHeaderConfig:
          editable: false

      title = @column.getHeaderTitle().down().getEl()

      @click(title).then =>
        expect(!!title.down('input')).toBe false

  describe 'timeframe dates', ->
    beforeEach ->
      @createPlanRecord()
      @createTimeframeRecord()

    afterEach ->
      @column.destroy()

    it 'should have an editable timeframe date', ->
      @createColumn()
      dateRange = @column.dateRange.getEl()
      if !Ext.isGecko
        @click(dateRange).then =>
          expect(!!@column.timeframePopover).toBe true

    it 'should have an uneditable timeframe date', ->
      @createColumn
        editPermissions:
          timeframeDates: false
      dateRange = @column.dateRange.getEl()
      @click(dateRange).then =>
        expect(!!@column.timeframePopover).toBe false

    describe 'when timeframe dates popover fires the save event', ->

      beforeEach ->
        @saveSpy = @spy @timeframeRecord, 'save'
        @createColumn()
        @column.onTimeframeDatesClick target: @column.dateRange.getEl()
        @column.timeframePopover.fireEvent 'save'

      it 'should save the timeframeRecord', ->
        expect(@saveSpy).toHaveBeenCalledOnce()

      it 'should fire the daterangechange event on the column', ->
        expect(@dateRangeChangeStub).toHaveBeenCalledOnce()

    describe 'timeframe date tooltip', ->

      it 'should have a timeframe date tooltip if user has edit permissions', ->
        @createColumn
          editPermissions:
            timeframeDates: true
        expect(this.column.dateRangeTooltip).toBeDefined()

      it 'should not have a timeframe date tooltip if user does not have edit permissions', ->
        @createColumn
          editPermissions:
            timeframeDates: false
        expect(this.column.dateRangeTooltip).toBeUndefined()

  describe 'header buttons', ->

    beforeEach ->
      @createPlanRecord()
      @createTimeframeRecord()

    describe 'delete plan button', ->

      it 'should show the delete plan button if the user has edit permissions', ->
        @createColumn(editPermissions: { deletePlan: true })
        expect(@column.deletePlanButton).toBeDefined()

      it 'should not show the delete plan button if the user does not have edit permissions', ->
        @createColumn(editPermissions: { deletePlan: false })
        expect(!!@column.deletePlanButton).toBe false

      describe 'when clicked', ->

        describe 'on column with features', ->

          beforeEach ->
            @createPlanRecord features: [{id: 1}, {id: 2}]
            @createColumn
              editPermissions: { deletePlan: true }
            @clickDeleteButton()

          it 'should not fire the deleteplan event', ->
            expect(@deletePlanStub).not.toHaveBeenCalled()

          it 'should show a confirmation dialog', ->
            expect(!!@confirmDialog).toBe true

          describe 'confirmation dialog', ->

            it 'should fire deleteplan when clicking Delete', ->
              @confirmDialog.down('#confirmButton').fireEvent 'click'
              expect(@deletePlanStub).toHaveBeenCalledOnce()

            it 'should not fire deleteplan when clicking Cancel', ->
              @confirmDialog.down('#cancelButton').fireEvent 'click'
              expect(@deletePlanStub).not.toHaveBeenCalled()

        describe 'on column without features', ->

          beforeEach ->
            @createColumn(editPermissions: { deletePlan: true })
            @clickDeleteButton()

          it 'should fire the deleteplan event', ->
            expect(@deletePlanStub).toHaveBeenCalledOnce()

          it 'should not show a confirmation dialog', ->
            expect(!!@confirmDialog).toBe false


  describe 'capacity calculation', ->
    beforeEach ->
      @createPlanRecord()
      @createTimeframeRecord()

    it 'should use preliminary estimate if the card does not have a refined estimate or it is zero', ->

      @createColumn()
      @column.isMatchingRecord = (record) ->
        record.data.RefinedEstimate <= 0

      @column.refresh()

      expect(@column.getHeaderTplData().pointTotal).toEqual 59

    it 'should use refined estimate if the card has a refined estimate', ->

      @createColumn()
      @column.isMatchingRecord = (record) ->
        record.data.RefinedEstimate > 0

      @column.refresh()

      expect(@column.getHeaderTplData().pointTotal).toEqual 15

    it 'calculation should use refined before preliminary estimate', ->
      @createColumn()
      expect(@column.getHeaderTplData().pointTotal).toEqual 74