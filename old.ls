d3.json \twCounty2015.topo.json, (topo) ->
  svg = d3.select \#svg
  geo-group = svg.append \g
  hex-group = svg.append \g
  box = document.body.getBoundingClientRect!
  geo = topo.objects.County_MOI_1041215.geometries
  proj = d3.geo.mercator!center([121,23.6]).scale(7000).translate([box.width/2,box.height/2])
  path = d3.geo.path!projection proj
  scale = d3.scale.linear!
    .domain [0,0.5,1]
    .range  <[#f20 #aaa #02f]>
  carto = d3.cartogram!
    .projection proj
    .value (d,i) -> 
      d.value = geo[i].value or 0
      d.value
  random-data = -> geo.map -> it.value = Math.random!
  calc = ->
    features = carto(topo, geo).features
    features.map (d,i) -> d.properties = geo[i]
    features

  render-features = ->
    geo-group.selectAll \path .data features
      ..exit!remove!
      ..enter!append \path
    geo-group.selectAll \path .attr do
      d: carto.path
      fill: -> scale it.value
      stroke: \#fff
      opacity: 0.1
      "stroke-width": 1

  size = 0.08
  pixsize = proj([121,20]).0 - proj([121 - size, 20]).0 + 1
  init-tile = ->
    list = []
    count = 0
    dx = size * Math.sqrt(4)/4  #Math.sqrt(3)/4
    xidx = 0
    for i from 118 til 123.2 by size
      xidx++
      yidx = 0
      for j from 22 til 26.5 by size /1.4
        p = proj [i + (yidx%2) * dx, j]
        list.push {x: p.0, y: p.1, fill: null, xidx: xidx, yidx: yidx}
        yidx++
        /*
        node = document.elementFromPoint p.0, p.1
        if node =>
          fill = d3.select(node).attr("fill")
        else fill = \none
        if !fill => fill = \none
        list.push {x: p.0, y: p.1, fill: fill} #i + (count%2) * dx, y: j}
        */
    return list

  hex-shape = (cx,cy,r) ->
    ret = [a for a from  0 to 360 by 60]
      .map -> it * Math.PI / 180
      .map (a) -> {x: Math.sin(a) * r + cx, y: Math.cos(a) * r + cy}
      .map -> "#{it.x},#{it.y}"
      .join \L
    return "M#{ret}Z"

  fetch-fill = ->
    hex-group.attr display: \none
    features.map -> it.properties._count = 0
    value-sum = features.map(-> it.properties.value).reduce(((a,b) -> a + b),0)
    tile-count = 0
    list.map (p) ->
      node = document.elementFromPoint p.x, p.y
      if node => [fill,data] = [(d3.select(node).attr("fill") or \#eee), node.datum!]
      else [fill,data] = [\none, null]
      p <<< {fill, data}
      if data => data.properties._count = (data.properties._count or 0) + 1
      tile-count++
    for f in features
      v-rate = f.properties.value / (value-sum or 1)
      c-rate = f.properties._count / (tile-count or 1)
      list.filter(->it.data == f).filter((t)->
        dx = if (t.yidx % 2) => 1 else -1
        idx = [
          [t.xidx - 1 , t.yidx]
          [t.xidx + 1 , t.yidx]
          [t.xidx     , t.yidx - 1]
          [t.xidx + dx, t.yidx - 1]
          [t.xidx     , t.yidx + 1]
          [t.xidx + dx, t.yidx + 1]
        ]
        for p in idx =>
          if p.0 < 0 or p.1 < 0 => 
  render-hex = ->
    hex-group.attr display: \block
    hex-group.selectAll \path .data list
      ..exit!remove!
      ..enter!append \path
    hex-group.selectAll \path .attr do
      d: -> hex-shape it.x, it.y, pixsize/2
      stroke: \#fff
    hex-group.selectAll \path .each ->
      node = d3.select(@)
      if node.attr(\fill) =>
        node = node.transition!duration 500
      node.attr do
        fill: -> if !it.fill => \#eee else it.fill
        opacity: 0.1

  list = init-tile!
  features = null

  run = ->
    random-data!
    features := calc!
    render-features!
    fetch-fill!
    render-hex!
  #setInterval (-> run), 1000
  run!
