﻿local res = getThisResource()
browser = {}
browserGUI = {}
BROWSER_DIMENSION = nil
local screenX,screenY = guiGetScreenSize()
local catNodes
local cachedElements = {}
local path = "client/browser/"
local xmlFiles = { ["objectID"] = getResourceConfig(path.."objects.xml"), ["skinID"] = getResourceConfig(path.."skins.xml"), ["vehicleID"] = getResourceConfig(path.."vehicles.xml"), ["favorites"] = (xmlLoadFile("client/browser/favorites.xml") or xmlCreateFile("client/browser/favorites.xml", "favorites")), ["lastUsed"] = (xmlLoadFile("client/browser/lastused.xml") or xmlCreateFile("client/browser/lastused.xml", "lastused")) }
local elementCatalogs = { ["objectID"]="object",["vehicleID"]="vehicle",["skinID"]="skin" }
local dropdownArray = { "All Categories", "Favorites", "Last used" }
local searchModel, searchMax
local isScrolling
local searchTimerDelay,ignoreSearch
local callbackFunction
local initialValues = { }
local rememberValues = {}
local returnX,returnY,returnZ,returnRX,returnRY,returnRZ,returnInterior
--number, string, boolean, color, posX, posY, posZ, rotX, rotY, rotZ, objectID, skinID, modelID, marker-type, pickup-type, plate, blip-icon
function createBrowser()
	browserGUI.window = guiCreateWindow 	( 0, 0, 0.25, 1, "Browse...", true )
	guiSetVisible ( browserGUI.window, false )
	browserGUI.dropdown = editingControl.dropdown:create{["x"]=12,["y"]=25,["width"]=screenX*0.25,["height"]=20,["dropWidth"]=screenX*0.25,["dropHeight"]=200,["relative"]=false,["parent"]=browserGUI.window,["rows"]=dropdownArray}
	browserGUI.list = browserList:create( 12, 85, screenX*0.25, screenY*1-112, { {["Element"]=0.95-(60/(screenX*0.25))},{["[ID]"]=40/(screenX*0.25)}},false, browserGUI.window )
	browserGUI.search = guiCreateEdit ( 12, 50, screenX*0.25, 30, "Search...", false, browserGUI.window )
	browserGUI.ok = guiCreateButton ( 12, screenY-24, screenX*0.09 - 2, 40, "OK", false, browserGUI.window )
	browserGUI.cancel = guiCreateButton ( screenX*0.09 + 12 + 2, screenY-24, screenX*0.09 - 2, 40, "Cancel", false, browserGUI.window )
	browserGUI.favorites = guiCreateButton ( screenX*0.18 + 12 + 2, screenY-24, screenX*0.07 - 2, 40, "❤", false, browserGUI.window )
	browserGUI.searchProgress = guiCreateLabel ( 0, 0, 1, 0.1, "", true )
	browserGUI.searchModel = guiCreateLabel ( 0, 0, 1, 0.1, "", true )
	guiSetVisible ( browserGUI.searchProgress, false )
	guiSetVisible ( browserGUI.searchModel, false )
	guiLabelSetColor ( browserGUI.searchProgress,0,0,0 )
	guiLabelSetColor ( browserGUI.searchModel,0,0,0 )
	guiWindowSetSizable ( browserGUI.window, false )
	--
	browserGUI.list:addCallback(browser.gridlistSelect)
	browserGUI.list:addDoubleClickCallback(browser.applySelected)

	addEventHandler ("onClientGUIClick",browserGUI.ok,browser.browserSelected,false)
	addEventHandler ("onClientGUIClick",browserGUI.cancel,browser.browserCancelled,false)
	addEventHandler ("onClientGUIClick",browserGUI.favorites,browser.browserFavourite,false)
end

function browser.initiate ( theType, initialCat, initialModel )
	if not ( initialCat ) then initialCat = 1 end
	browser.dropdownSelected  = initialCat
	searchModel = initialModel
	--note: mainElement is defined in preview element
	if isElement ( mainElement ) then
		destroyElement ( mainElement )
		mainElement = nil
	end
	initiatedType = theType
	guiSetText ( browserGUI.search, "Search..." )
	--We need to recreate our dropdown
	browserGUI.dropdown:destroy()
	--
	browserGUI.list:enable(cc.browser_up,cc.browser_down)
	catNodes = { cachedElements[initiatedType], cachedElements["favorites"], cachedElements["lastUsed"] }
	progress = #dropdownArray + 1
	createCategoriesTable ( cachedElements[initiatedType] )
	--
	browserGUI.dropdown = editingControl.dropdown:create{["x"]=12,["y"]=25,["width"]=screenX*0.25,["height"]=20,["dropWidth"]=screenX*0.25,["dropHeight"]=200,["relative"]=false,["parent"]=browserGUI.window,["rows"]=dropdownArray}
	browserGUI.dropdown:setValue(initialCat)
	--
	BROWSER_DIMENSION = editor_main.getWorkingDimension() + 3
	setElementDimension ( localPlayer, BROWSER_DIMENSION )
	setPlayerHudComponentVisible ( "radar", false )
	setSkyGradient(112,112,112,112,112,112)
	setCameraInterior ( 14 )
	guiSetVisible ( browserGUI.window, true )
	--Output a default search
	local results = elementSearch ( catNodes[initialCat],"" )
	browser.output ( results )
	if initialModel then
		for k,searchTable in ipairs(results) do
			if tonumber(searchTable["model"]) == initialModel then
				browserGUI.list:setSelected(k)
				browserGUI.list:centre(k)
				break
			end
		end
	end
	guiSetInputEnabled ( false )
end

function startBrowser ( elementType, callback, initialCat, initialModel, rememberLast )
	if not xmlFiles[elementType] then return false end
	if not callback then return false end
	if not cachedElements[elementType] then
		cachedElements[elementType] = cacheElements(xmlFiles[elementType], elementCatalogs[elementType])
	end
	cachedElements["favorites"] = cacheElements(xmlFiles["favorites"], elementCatalogs[elementType])
	cachedElements["lastUsed"] = cacheElements(xmlFiles["lastUsed"], elementCatalogs[elementType])
	browser.enabled = true
	returnX,returnY,returnZ,returnRX,returnRY,returnRZ = getCameraMatrix()
	returnInterior = getCameraInterior()
	callbackFunction = callback
	setFreelookEvents(true)
	addEventHandler ( "onClientRender", getRootElement(), rotateMesh )
	addEventHandler ( "onClientGUIWorldClick", getRootElement(), browser.searchClick )
	bindControl ( "toggle_cursor", "down", browser.toggleCursor )
	bindControl ( "browser_confirm", "down", browser.browserSelected )
	if tutorialVars.browserBind == elementType then
		tutorialNext ()
	end
	guiSetVisible ( browserGUI.searchProgress,true)
	guiSetVisible ( browserGUI.searchModel,true)
	setCameraMatrix ( tx,ty,tz )
	browserElementLookOptions.up = "browser_zoom_in"
	browserElementLookOptions.down = "browser_zoom_out"

	-- Save the initial values for if the player clicks in Cancel button
	initialValues.initialType = elementType
	initialValues.initialCat = initialCat
	initialValues.initialModel = initialModel
	rememberValues[elementType] = rememberValues[elementType] or {}
	rememberValues[elementType].category = rememberValues[elementType].category or initialCat
	rememberValues[elementType].model = rememberValues[elementType].model or initialModel
	if rememberLast == true then --Shortcuts system.  This means the editor accessed the model browser automatically and the player did not choose the specified model
		browser.initiate ( elementType, rememberValues[elementType].category, rememberValues[elementType].model )
	else
		browser.initiate ( elementType, initialCat, initialModel )
	end
	return true
end

function browser.close()
	browser.enabled = false
	unbindControl ( "toggle_cursor", "down", browser.toggleCursor )
	unbindControl ( "browser_up", "both", browser.scroll )
	unbindControl ( "browser_down", "both", browser.scroll )
	unbindControl ( "browser_confirm", "down", browser.browserSelected )
	browser.outputTable = {}
	setFreelookEvents(false)
	removeEventHandler ( "onClientGUIWorldClick", getRootElement(), browser.searchClick )
	removeEventHandler ( "onClientRender", getRootElement(), rotateMesh )
	setCameraInterior ( returnInterior )
	resetSkyGradient()
	setPlayerHudComponentVisible ( "radar", true )
	if isElement ( browser.mainElement ) then
		setElementAlpha(browser.mainElement, 255)
		destroyElement ( browser.mainElement )
		browser.mainElement = nil
	end
	setElementDimension ( localPlayer, editor_main.getWorkingDimension() )
	guiSetVisible ( browserGUI.window, false )
	setProgressText ( "" )
	setModelText ( "" )
	browserGUI.list:disable()
	guiSetVisible ( browserGUI.searchProgress,false)
	guiSetVisible ( browserGUI.searchModel,false)
	setCameraMatrix ( returnX,returnY,returnZ,returnRX,returnRY,returnRZ )
end

function browser.gridlistSelect (cellrow)
	searchModel = false
	if cellrow == 0 then
		if ( browser.mainElement ) then
			if isElement(browser.mainElement) then
				setElementAlpha(browser.mainElement, 0)
				setProgressText ( "" )
				setModelText ( "" )
			end
		end
		return
	end
	local model = tonumber(browserGUI.list:getSelectedText()[2])
	browserSetElementModel ( initiatedType, model)
	setProgressText ( (cellrow) .." / "..searchMax )
	local name = browserGUI.list:getSelectedText()[1]
	setModelText ( name.." ["..model.."]" )
	if not isCursorShowing() then
		if isElement(browser.mainElement) then
			enableElementLook(true,browser.mainElement)
		end
		removeEventHandler ( "onClientRender", getRootElement(), rotateMesh )
	end
	if ( tutorialVars.callBack ) then
		tutorialNext()
	end
end

local query
function browser.search ( element )
	if element == browserGUI.search then
		local text = guiGetText ( element )
		--
		if text == "Search..." then return end
		local newtext = string.gsub(text, "[^%w^_^%s]", "")
		if text ~= newtext then
			guiSetText ( element, newtext )
		end
		if ignoreSearch == true then ignoreSearch = false return end
		ignoreSearch = false
		for k,v in ipairs(getTimers()) do
			if v == searchTimerDelay then
				killTimer(searchTimerDelay)
				break
			end
		end
		searchTimerDelay = setTimer ( browser.prepareSearch, 250, 1 )
	end
end
addEventHandler ( "onClientGUIChanged", getRootElement(), browser.search )

function browser.prepareSearch()
	query = guiGetText ( browserGUI.search ) --get the query
	local cellrow = browserGUI.dropdown:getRow() --get the category
	if cellrow == -1 then cellrow = 0 end
	if not catNodes then return end
	local cache = catNodes[cellrow] --get the node from the category
	if ( query == "Search..." ) then query = "" end
	local results = elementSearch ( cache, query )
	browser.output ( results )
end

function browser.output ( cachetable )
	searchMax = #cachetable
	local newTable = {}
	for k,searchTable in ipairs(cachetable) do
		table.insert ( newTable, { searchTable["name"],searchTable["model"] } )
	end
	browserGUI.list:setRows(newTable)
end

function createCategoriesTable ( node, nodeid )
	if nodeid == nil then nodeid = 1 end
	--outputDebugString ( "dReached 1", 3 )
	for k,value in pairs(node) do
		--if nodeid == 0 then --outputDebugString ( "dReached 2", 3 ) end
		if ( type(k) == "string" ) then --if its a category
			--do stuff
			local reps = string.rep("|  ", nodeid)
			if reps == nil or reps == false then reps = "" end
			local name = k

			dropdownArray[progress] =  reps.."|--"..name
			catNodes[progress] = value
			progress = progress + 1
			createCategoriesTable ( value, nodeid + 1 )
		end
	end
	--outputDebugString ( "dReached 4", 3 )
end

function browser.searchClick()
	if source == browserGUI.search then
		local text = guiGetText ( source )
		if text == "Search..." or text == "Search" then
			ignoreSearch = true
			guiSetText ( source, "" )
		end
		guiSetInputEnabled ( true )
	else
		local text = guiGetText ( browserGUI.search )
		if text == "" then
			guiSetText ( browserGUI.search, "Search..." )
		end
		guiSetInputEnabled ( false )
	end
end

function browser.dropdownSelect ( element )
	if browserGUI.dropdown:getRow() ~= browser.dropdownSelected then
		browser.dropdownSelected = browserGUI.dropdown:getRow()
		browser.prepareSearch()
	end
end
addEventHandler ( "onClientDropDownSelect", getRootElement(), browser.dropdownSelect )


function browser.toggleCursor()
	if tutorialVars.browserDisableCursor then return end
	if not browser.enabled then --if for some reason the bind remained after quitting,,,
		unbindControl ( "toggle_cursor", "down", browser.toggleCursor )
		return
	end
	if browserGUI.list:getSelected() == 0 then return end

	local showing = isCursorShowing()
	if not showing then
		showCursor(true)
		disableElementLook(true)
		guiSetVisible ( browserGUI.window,true)
		originalRotateTick = getTickCount() - previewTickDifference
		addEventHandler ( "onClientRender", getRootElement(), rotateMesh )
		local model = tonumber(browserGUI.list:getSelectedText()[2])
		browserSetElementModel ( initiatedType, model )
	else
		showCursor(false)
		guiSetVisible ( browserGUI.window,false)
		if isElement(browser.mainElement) then
			enableElementLook(true,browser.mainElement,270,-15)
		end
		removeEventHandler ( "onClientRender", getRootElement(), rotateMesh )
	end
end

function browser.browserSelected(button)
	if button ~= "left" and button ~= "browser_confirm" then return end

	browser.applySelected()
end

function browser.saveLastUsed(model,name)
  local nodes = xmlNodeGetChildren(xmlFiles["lastUsed"])
  for i,n in ipairs(nodes)do
    if xmlNodeGetAttribute(n,"model") == tostring(model) then
      xmlDestroyNode(n)
      break
    end
  end
  local node = xmlCreateChild(xmlFiles["lastUsed"], elementCatalogs[initiatedType])
  xmlNodeSetAttribute(node, "model", model)
  xmlNodeSetAttribute(node, "name", name)
  xmlNodeSetAttribute(node, "keywords", "")
  xmlSaveFile(xmlFiles["lastUsed"])
end

function browser.checkForFavorite()
	local model = browserGUI.list:getSelectedText()[2]
	if ( model ) and ( model ~= "" ) then
    if browser.isInFavourite(model) then
      guiSetProperty( browserGUI.favorites, "NormalTextColour", tocolor(0,255,0,255) )
      guiSetProperty( browserGUI.favorites, "HoverTextColour", tocolor(0,255,0,255) )
    else
      guiSetProperty( browserGUI.favorites, "NormalTextColour", tocolor(255,0,0,255) )
      guiSetProperty( browserGUI.favorites, "HoverTextColour", tocolor(255,0,0,255) )
    end
  end
end

function browser.isInFavourite(model)
  local nodes = xmlNodeGetChildren(xmlFiles["favorites"])
  local model = tostring(model)
  for i,n in ipairs(nodes)do
    if xmlNodeGetAttribute(n,"model") == model then
      return true
    end
  end
  return false
end

function browser.applySelected()
	if tutorialVars.browserDisableKeys then return end
	local selection = browserGUI.list:getSelected()
	if selection == 0 then return end

	local cat = browserGUI.dropdown:getRow()
	local model = browserGUI.list:getSelectedText()[2]
	if ( model ) and ( model ~= "" ) then
		if callbackFunction then
			callbackFunction(initiatedType,cat,tonumber(model))
			rememberValues[initiatedType].category = cat
			rememberValues[initiatedType].model = tonumber(model)
      local name = browserGUI.list:getSelectedText()[1]
      browser.saveLastUsed(tonumber(model),name)
		end
		if ( tutorialVars.browserOK == initiatedType ) then
			tutorialNext ()
		end
	end
	browser.close()
end

function browser.browserFavourite(button)
	if button == "left" then
    local model = browserGUI.list:getSelectedText()[2]
    if ( model ) and ( model ~= "" ) then
      if browser.isInFavourite(model) then
        local nodes = xmlNodeGetChildren(xmlFiles["favorites"])
        local model = tostring(model)
        for i,n in ipairs(nodes)do
          if xmlNodeGetAttribute(n,"model") == model then
            xmlDestroyNode(n)
            break
          end
        end
      else
        local name = browserGUI.list:getSelectedText()[1]
        local node = xmlCreateChild(xmlFiles["favorites"], elementCatalogs[initiatedType])
        xmlNodeSetAttribute(node, "model", model)
        xmlNodeSetAttribute(node, "name", name)
        xmlNodeSetAttribute(node, "keywords", "")
        xmlSaveFile(xmlFiles["favorites"])
      end
      cachedElements["favorites"] = cacheElements(xmlFiles["favorites"], elementCatalogs[initiatedType])
      catNodes[2] = cachedElements["favorites"]
      browser.checkForFavorite()
      if browserGUI.dropdown:getRow() == 2 then
          browser.prepareSearch()
      end
    end
  else
    if browserGUI.dropdown:getRow() == 2 then
      local selected = browserGUI.list:getSelectedText()
      if selected then
        local name = browserGUI.list:getSelectedText()[1]
        local model = browserGUI.list:getSelectedText()[2]
        if ( model ) and ( model ~= "" ) then
          inputGui("Rename "..name.." to ...","Write new name",function(button,state,newName,modelID)
            if string.len(newName) > 0 and string.len(newName) < 30 then
              local nodes = xmlNodeGetChildren(xmlFiles["favorites"])
              local model = tostring(model)
              for i,n in ipairs(nodes)do
                if xmlNodeGetAttribute(n,"model") == modelID then
                  xmlNodeSetAttribute(n, "name", newName)
                  cachedElements["favorites"] = cacheElements(xmlFiles["favorites"], elementCatalogs[initiatedType])
                  catNodes[2] = cachedElements["favorites"]
                  browser.prepareSearch()
                  break
                end
              end
            end
          end,tostring(model))
        end
      end
    end
  end
end

function browser.browserCancelled(button)
	if button ~= "left" then return end
	if ( tutorialVars.browserOK ) then return end

	if callbackFunction then
		callbackFunction(initialValues.initialType, initialValues.initialCat, initialValues.initialModel,true)
	end
	browser.close()
end

function setProgressText ( text )
	guiSetText ( browserGUI.searchProgress, text )
	local length = guiLabelGetTextExtent ( browserGUI.searchProgress )
	local x = screenX - length
	guiSetPosition ( browserGUI.searchProgress, x + 1, 1, false )
end

function setModelText ( text )
	guiSetText ( browserGUI.searchModel, text )
	local length = guiLabelGetTextExtent ( browserGUI.searchModel )
	local x = screenX - length
	guiSetPosition ( browserGUI.searchModel, x + 1, 17, false )
end

function showCursor(state)
	return editor_main.showCursor (state)
end

addEventHandler("onClientResourceStop", resourceRoot,
function ()
  xmlSaveFile(xmlFiles["favorites"])
  xmlSaveFile(xmlFiles["lastUsed"])
  xmlUnloadFile(xmlFiles["favorites"])
  xmlUnloadFile(xmlFiles["lastUsed"])
end)

local lastCallTick = 0

function toggleFavourite (gridlist)
	if getTickCount() - lastCallTick < 500 then return end --Since it always gets called at least twice per click
	lastCallTick = getTickCount()
	if not gridlist then return end
	local item = guiGridListGetSelectedItem(gridlist)
	local name = guiGridListGetItemText(gridlist, item, 1)
	local model = guiGridListGetItemText(gridlist, item, 2)
	if not model or not tonumber(model) then return end
	local results = elementSearch(catNodes[2], model)
	for i, data in pairs(results) do
		if data["model"] == model then --has to be exact match
			for i, node in pairs(xmlNodeGetChildren(xmlFiles["favorites"])) do
				if xmlNodeGetAttribute(node, "model") == model then
					xmlDestroyNode(node)
					break
				end
			end
			cachedElements["favorites"] = cacheElements(xmlFiles["favorites"], elementCatalogs[initiatedType])
			catNodes[2] = cachedElements["favorites"]
			if browserGUI.dropdown:getRow() == 2 then
				browser.prepareSearch() --to force reload of 'Favorites'
			end
			outputMessage(elementCatalogs[initiatedType]:gsub("^%l", string.upper) .. " '" .. name .. "' removed from favorites.", 50, 255, 50)
			return
		end
	end
	local node = xmlCreateChild(xmlFiles["favorites"], elementCatalogs[initiatedType])
	xmlNodeSetAttribute(node, "model", model)
	xmlNodeSetAttribute(node, "name", name)
	xmlNodeSetAttribute(node, "keywords", "")
	cachedElements["favorites"] = cacheElements(xmlFiles["favorites"], elementCatalogs[initiatedType])
	catNodes[2] = cachedElements["favorites"]
	outputMessage(elementCatalogs[initiatedType]:gsub("^%l", string.upper) .. " '" .. name .. "' added to favorites.", 50, 255, 50)
end
