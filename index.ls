tilemap = {}
tilemap.cartogram = do
  container: null
  store: do
    projection: d3.geo.mercator!
    value: (d,i) -> Math.round(Math.random! * 100)
    topojson: null
    object: null
  init: (root, topojson, object) ->
    @store <<< {topojson, object}
    @container = root.append \g
  projection: -> @store.projection = it
  value: -> @store.value = it
  features: ->
    @carto = d3.cartogram!
      .projection @store.projection
      .value @store.value
    @store.features = @carto(@store.topojson, @store.object).features
    @store.features.map (d,i) ~> d.properties = @store.object[i].properties
    @store.features
  render: ->
    @container.selectAll \path .data @store.features
      ..exit!remove!
      ..enter!append \path
    @container.selectAll \path .attr {d: @carto.path}
    @store.features.forEach ~> it.properties.area = @carto.path.area it
    @store.area = @store.features.reduce(((a,b) -> b.properties.area + a), 0)
  pin: (x, y) ->
    node = document.elementFromPoint x,y
    if node and d3.select(node).datum! => return {node: node, data: d3.select(node).datum!}
    return null

tilemap.hexagon = do
  map: []
  list: []
  container: null
  init: (root,cartogram,step=1) ->
    @container = root.append \g
    @cartogram = cartogram
    @step = step
    [@map,@list] = [[],[]]
    box = cartogram.container.0.0.getBoundingClientRect!
    [xlen,ylen] = [Math.round(box.width/(2 * step)) + 1, Math.round(box.height/(step*0.8660254037844386)) + 1]
    @map = d3.range(ylen).map(-> d3.range(xlen).map(->null))
    @list = []
    for x from 0 til xlen => for y from 0 til ylen =>
      obj = do
        idx: {x, y}
        x: (x + (y % 2)/2) * step * 3 + box.left
        y: y * step * 0.8660254037844386 + box.top
        r: step
      @map[y][x] = obj
      @list.push obj
  bind: ->
    @container.selectAll \path .attr {display: \none}
    @container.selectAll \line .attr {display: \none}
    for item in @list =>
      item.pin = null
      hash = {}
      for i from 0 til 5 =>
        a = Math.random! * Math.PI * 2
        r = @step * Math.random!
        ret = @cartogram.pin item.x + r * Math.cos(a), item.y + r * Math.sin(a)
        if ret =>
          name = ret.data.properties.C_Name
          if !hash[name] => hash[name] = {pin: ret, count: 0}
          hash[name].count++
      list = [v for k,v of hash]
      list.sort (a,b) -> b.count - a.count
      if list.0 => item.pin = list.0.pin
    @boundary!
  path: (cx,cy,r) ->
    ret = [a for a from  0 to 360 by 60]
      .map -> (it + 90) * Math.PI / 180
      .map (a) -> {x: Math.sin(a) * r + cx, y: Math.cos(a) * r + cy}
      .map -> "#{it.x},#{it.y}"
      .join \L
    return "M#{ret}Z"
  render: ->
    @container.selectAll \path .data @list
      ..exit!remove!
      ..enter!append \path
    @container.selectAll \path
      .attr { display: \block, d: ~> @path it.x, it.y, it.r }
      .each (d,i) -> d.node = @
    @container.selectAll \line .data @boundaries
      ..exit!remove!
      ..enter!append \line
    @container.selectAll \line .attr do
      x1: -> it.x1
      x2: -> it.x2
      y1: -> it.y1
      y2: -> it.y2
      stroke: \#000
      "stroke-width": 2
      display: \block
  boundary: ->
    @boundaries = []
    @list.map (d,i) ~>
      [idx,angle] = [d.idx, -1]
      dx = if idx.y % 2 => 1 else 0
      isBoundary = false
      for item in [[0 -2],[dx,-1],[dx,1],[0 2],[dx - 1,1],[dx - 1,-1]] =>
        angle++
        [tx,ty] = [idx.x + item.0, idx.y + item.1]
        src = d.pin
        des = if @map[ty] and @map[ty][tx] => @map[ty][tx].pin else null
        if (src or {}).data == (des or {}).data => continue
        x1 = d.x + @step * Math.sin(Math.PI * 2 * (angle - 0.5) / 6)
        x2 = d.x + @step * Math.sin(Math.PI * 2 * (angle + 0.5) / 6)
        y1 = d.y - @step * Math.cos(Math.PI * 2 * (angle - 0.5) / 6)
        y2 = d.y - @step * Math.cos(Math.PI * 2 * (angle + 0.5) / 6)
        @boundaries.push {idx, angle, x1, x2, y1, y2}
  flip: (x,y,target) ->
    if !@map[y] or !@map[y][x] => return
    d = @map[y][x]
    idx = d.idx
    dx = if idx.y % 2 => 1 else -1
    hash = {}
    for item in [[-1 0],[1 0],[0 -1],[dx,-1],[0 1],[dx,1]] =>
      [tx,ty] = [idx.x + item.0, idx.y + item.1]
      if @map[ty] and @map[ty][tx] and @map[ty][tx].pin =>
        hash[@map[ty][tx].pin.data.properties.C_Name] = @map[ty][tx].pin
      else hash[""] = null
    keys = [k for k of hash]
    keys.sort!
    idx = keys.indexOf(if d.pin => d.pin.data.properties.C_Name else "")
    if target? => d.pin = target
    else d.pin = hash[keys[(idx + 1 ) % keys.length]]
    @boundary!

angular.module \main, <[]>
  ..controller \main, <[$scope $timeout]> ++ ($scope,$timeout) ->
    $scope.counties = []
    d3.json \twCounty2015.topo.json, (topo) ->
      svg = d3.select \#svg
      color = d3.scale.category20!
      box = svg.0.0.getBoundingClientRect!
      proj = d3.geo.mercator!center([121,23.6]).scale(7000).translate([box.width/2,box.height/2])
      proj2 = (coord)->
        if coord.1 > 25.5 => coord.1 -= 1
        if coord.0 < 119 => coord.0 += 1.2
        return proj coord
      [carto,tile] = [tilemap.cartogram, tilemap.hexagon]
      carto
        ..init svg, topo, topo.objects.County_MOI_1041215.geometries
        ..projection proj2
        ..features!
        ..render!

      $scope.$apply ->
        $scope.counties = carto.store.features.map -> do
          name: it.properties.C_Name, value: Math.round(Math.random!*100)

      carto.container.selectAll \path .attr do
        opacity: 0.1
        stroke: \#fff
        "stroke-width": 0
      tile
        ..init svg, carto, 12
        ..bind!
        ..render!
      draw = ->
        tile.container.selectAll \line .attr do
          opacity: 0.9
        tile.container.selectAll \path .attr do
          fill: (d,i) ->
            if !d.pin => return \#fff 
            return color(d.pin.data.properties.C_Name)
          stroke: \#fff
          opacity: 0.9
      /*tile.container.selectAll \path .on \click, (d,i) ->
        tile.flip d.idx.x, d.idx.y
        draw!
      */
      draw!

      $scope.handler = null
      $scope.handle = ->
        carto
          ..value (d,i) -> 
            properties = carto.store.object[i].properties
            ret = $scope.counties.filter(->it.name == properties.C_Name).0
            if ret => return ret.value or 0.1
            return 1
          ..features!
          ..render!
        tile.bind!
        tile.render!
        draw!
      $scope.$watch 'counties', (o,n) ->
        if $scope.handler => $timeout.cancel $scope.handler
        $scope.handler = $timeout (->
          $scope.handle!
          $scope.handler = null
        ), 100
      , true
