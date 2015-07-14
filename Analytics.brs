Function Analytics(device_id as String, apikey as string, port as Object) as Object
	if GetGlobalAA().DoesExist("Analytics")
		return GetGlobalAA().Analytics
	else

		appInfo = CreateObject("roAppInfo")
		this = {
			type: "Analytics"
			version: "1.0.0"

			apikey: apikey

			Init: init_analytics
			Submit: submit_analytics
			AddEvent: add_analytics
			ViewScreen: ViewScreen
			AddSessionDetails: AddSessionDetails
			HandleAnalyticsEvents: handle_analytics
			GetGeoData: getGeoData_analytics

			AppVersion: appInfo.GetVersion()

			device_id: device_id
			port: port

			useGeoData: true
			geoData: invalid

			queue: invalid
			timer: invalid

			session_id: AnalyticsDateTime()
			event_id: 0

			lastRequest: invalid
		}

		GetGlobalAA().AddReplace("Analytics", this)
		this.init()
	end if

	return this

End Function

Function init_analytics() as void
	if m.useGeoData = true
		m.GetGeoData()
	end if

	m.SetModeCaseSensitive()

	m.queue = CreateObject("roArray", 0, true)

	m.timer = CreateObject("roTimeSpan")
	m.timer.mark()

	print "Anlytics Initialized..."

End Function

Function ViewScreen(screenName as String)
	event = CreateObject("roAssociativeArray")
	event.event_type = "Screen View"
	event.event_properties = CreateObject("roAssociativeArray")
	event.event_properties.screen_name = screenName
	m.AddSessionDetails(event)
	m.queue.push(event)
End Function

Function add_analytics(eventName as string, properties = invalid as Object)
	event = CreateObject("roAssociativeArray")
	event.event_type = eventName
	event.event_properties = properties
	m.AddSessionDetails(event)
	m.queue.push(event)
End Function

Function AddSessionDetails(event as Object)
	m.event_id = m.event_id + 1

	device = CreateObject("roDeviceInfo")
	device_details = device.GetModelDetails()

	event.time = AnalyticsDateTime()
	event.device_id = m.device_id
	event.app_version = m.AppVersion
	event.platform = "Roku"
	event.session_id = m.session_id
	event.event_id = m.event_id

	event.device_manufacturer = device_details.VendorName
	event.device_model = device_details.ModelNumber

	event.os_name = "Roku"
	event.os_version = device.GetVersion()

	event.language = device.GetCurrentLocale()

	if m.geoData <> invalid
		location = CreateObject("roAssociativeArray")
		if m.geoData.DoesExist("country_code") then event.country = m.geoData.country_code
		if m.geoData.DoesExist("city") then event.city = m.geoData.city
		if m.geoData.DoesExist("longitude") then event.location_lng = m.geoData.longitude
		if m.geoData.DoesExist("latitude") then event.location_lat = m.geoData.latitude
		if m.geoData.DoesExist("ip") then event.ip = m.geoData.ip
	end if

	event.user_properties = CreateObject("roAssociativeArray")
	screen = CreateObject("roAssociativeArray")
	screen.width = device.GetDisplaySize().w
	screen.height = device.getDisplaySize().h
	screen.type = device.GetDisplayType()
	screen.mode = device.GetDisplayMode()
	screen.ratio = device.GetDisplayAspectRatio()
	event.user_properties.screen = screen
	event.user_properties.device = device.GetModelDisplayName()

End Function

Function submit_analytics() as Void

	if m.queue.count() > 0 THEN
		print "Submitting Analytics..."

		eventsJson = FormatJson(m.queue)
		PostString = "api_key=" + m.apiKey + "&event=" + eventsJson

		m.queue.clear()

		transfer = CreateObject("roUrlTransfer")
		transfer.SetUrl("https://api.amplitude.com/httpapi")
		transfer.SetPort(m.port)
		transfer.EnablePeerVerification(false)
		transfer.EnableHostVerification(false)
		transfer.RetainBodyOnError(true)

		m.lastRequest = transfer

		transfer.AsyncPostFromString(PostString)

	end if
	m.timer.mark()

End Function

Function handle_analytics(msg)
	if m.timer.totalSeconds() > 60 then
		m.Submit()
	end if

	if type(msg) = "roUrlEvent" AND m.lastRequest <> invalid AND m.lastRequest.GetIdentity() = msg.GetSourceIdentity()
		responseString = msg.GetString()

		'Check for errors
		if responseString <> "success"
			Print "*** There was an error submitting Analytics to Amplitude: " + responseString
		end if

		m.lastRequest = invalid
	End If

End Function

Function AnalyticsDateTime() as Integer
	date = CreateObject("roDateTime")
	return date.AsSeconds()
End Function


'This queries the telize open GeoIP service Telize to get Geo and public IP data
Function getGeoData_analytics()
	url = "http://www.telize.com/geoip"

	transfer = CreateObject("roUrlTransfer")
	transfer.SetUrl(url)
	data = transfer.GetToString()

	object = ParseJSON(data)
	m.geoData = object
End Function
