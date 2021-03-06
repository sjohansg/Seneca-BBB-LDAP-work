<%@page import="java.util.ArrayList"%>
<%@page import="java.util.Collections"%>
<%@page import="java.util.Date"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="org.apache.commons.lang.StringUtils"%>
<%@page import="redis.clients.jedis.*" language="java" %>
<%@ include file="bbb_api.jsp"%>

<%!
	private final static char PROF_SYMBOL = '`';
	private final static char USERID_HEADER = '$';
	private final static char DELIMITER = '~';
	private final static char NAME_DELIMITER = '^';
	public final static String MEETING_LIST = "AllRecordings";
	
	public static Jedis dbConnect(){
		String serverIP = "127.0.0.1";
		JedisPool redisPool = new JedisPool(serverIP, 6379);
		try{
			return redisPool.getResource();
		}
		catch (Exception e){
			System.err.print("Error in MeetingApplication.dbConnect():");
			System.err.println(e.toString());
		}
		System.err.println("Returning NULL from dbConnect()");
		return null; 
	}


	// COMPRESSION AND EXTRACTION
	// --------------------------
	
	public String compressMeeting(String meetingName, String modPass, String viewPass, String allowGuests, String recordable){
		return compressMeeting(meetingName, modPass, viewPass, Boolean.parseBoolean(allowGuests), Boolean.parseBoolean(recordable));
	}
			
	public String compressMeeting(String meetingName, String modPass, String viewPass, Boolean allowGuests, Boolean recordable){
		StringBuilder sb = new StringBuilder();
		
		// Meeting Name (Field [0])
		sb.append(meetingName);
		sb.append(DELIMITER);
		
		// Moderator Password (Field [1])
		sb.append(modPass);
		sb.append(DELIMITER);
		
		// Viewer Password (Field [2])
		sb.append(viewPass);
		sb.append(DELIMITER);
		
		// Guests Allowed (True/False) (Field [3])
		sb.append(allowGuests.toString());
		sb.append(DELIMITER);
		
		// Recordable (True/False) (Field [4])
		sb.append(recordable.toString());
		sb.append(DELIMITER);
		
		// Date Last Edited (Field [5])
		SimpleDateFormat df = new SimpleDateFormat("yyyy/MM/dd aa HH:mm");
		Date date = new java.util.Date();
		sb.append(df.format(date));
		
		String dataString = sb.toString();
		return dataString;
	}
	
	public String[] decompress(String rawData){
		String components[] = StringUtils.split(rawData, DELIMITER);
		return components;
	}
	
	public String extractName(String presenterKey, String fieldKey, Jedis jedis){
		String components[] = decompress(jedis.hget(presenterKey, fieldKey));
		return components[0];
	}
	
	// -- COMPRESSION, EXTRACTION
	
	// SAVING TO REDIS
	// General save method
	public void saveMeeting(String presenterKey, String meetingName, String modPass, String viewPass, Boolean allowGuests, Boolean recordable){
		presenterKey = USERID_HEADER + presenterKey;
		Jedis jedis = dbConnect();
		Boolean newMeeting = true;
		String dataString = compressMeeting(meetingName, modPass, viewPass, allowGuests, recordable);
		// Goes through all meetings associated with the presenterKey and compares the names
		for (int i = 1; i <= jedis.hlen(presenterKey); i++){
			String oldName = extractName(presenterKey, "meeting"+i, jedis);
			if (meetingName.compareTo(oldName) == 0){
				newMeeting = false;
				jedis.hset(presenterKey, "meeting"+i, dataString);
			} // Compare new meeting to old meeting
		} // For loop
		if (newMeeting){
			jedis.hset(presenterKey, "meeting"+(jedis.hlen(presenterKey)+1), dataString);
		} // Save new meeting
		//Regardless of if the meeting is new, we want to save the meeting ID in allMeetings if it is recordable.
		if (recordable){
			saveRecordable(presenterKey, meetingName, jedis);
		}
	}
	
	// Saving recordable meeting IDs to the allMeetings string
	private void saveRecordable(String presenterKey, String meetingName, Jedis jedis){
		if (!jedis.hexists(MEETING_LIST, presenterKey)){
			// If the allMeetings field does not exist, create it and save the meetingName all at once
			jedis.hset(MEETING_LIST, presenterKey, meetingName);
		} else{
			// Search the allMeetings string for the meetingName
			String dataString = jedis.hget(MEETING_LIST, presenterKey);

			if (dataString.indexOf(meetingName) == -1) { //if the meetingName isnt already there
				dataString += DELIMITER + meetingName;   //add it to the string
				jedis.hset(MEETING_LIST, presenterKey, dataString); //save the string
			}
		}
	}

	// -- SAVING

	// DELETING A MEETING
	public String deleteMeeting(String presenterKey, String meetingName){
		presenterKey = USERID_HEADER + presenterKey;
		Jedis jedis = dbConnect();
		try {
			// Find the number of meetings for this presenter
			Integer numMeetings = jedis.hlen(presenterKey).intValue();
			Integer target = 0;
			int position = 1;
			Boolean found = false;
			while (!found && position <= numMeetings){
				// Find the meeting that matches that name
				if (meetingName.compareTo(extractName(presenterKey, "meeting"+position, jedis)) == 0){
					// Save which "position" that meeting is at (meeting1, meeting2....)
					target = position;
					found = true;
				}
				position++;
			}
			if (target > 0){
				// If meeting position == number of meetings, just flat-out delete it
				if (target == numMeetings){
					jedis.hdel(presenterKey, "meeting"+numMeetings);
				}
				// Else, copy meeting(n+1) into meeting(n) until meeting(n+1) doesn't exist, and then delete meeting(n+1)
				else{
					for (position = target; position < numMeetings; position++){
						String nextMeeting = jedis.hget(presenterKey, "meeting"+(position+1));
						jedis.hset(presenterKey, "meeting"+position, nextMeeting);
					}
					jedis.hdel(presenterKey, "meeting"+numMeetings);
				}
			}
			else {}
		}
		catch (Exception e){
			e.printStackTrace();
		}
			
		return "<response><returncode>SUCCESS</returncode><deleted>true</deleted></response>";
	}
	// -- DELETING
	
	// This method accepts an ArrayList of decompressed meetings (works for both meetings and lectures) and returns
	// an ArrayList of those meetings/lectures which are currently running.
	public ArrayList <String[]> runningList(ArrayList <String[]> meetings){
		ArrayList <String[]> openMeetings = new ArrayList <String[]> ();
		for (int i = 0; i < meetings.size(); i ++){

			if (isMeetingRunning(meetings.get(i)[0]).equals("true")){

				openMeetings.add(meetings.get(i));
			}
		}
		return openMeetings;
	}
%>