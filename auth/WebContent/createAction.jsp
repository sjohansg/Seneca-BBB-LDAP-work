<jsp:useBean id="ldap" class="ldap.LDAPAuthenticate" scope="session"/>

<%
if(!ldap.getAuthenticated().equals("true")) {
    response.sendRedirect("login.jsp");	
}

String mPwd = request.getParameter( "mPwd" );
String mPwdre = request.getParameter( "mPwdre" );
String vPwd = request.getParameter( "vPwd" );
String vPwdre = request.getParameter( "vPwdre" );
String meetingName = request.getParameter( "meetingName" );

// checking no fields to be empty
if(mPwd.length()  == 0 || mPwdre.length() == 0 || vPwd.length() == 0 || vPwdre.length() == 0  || meetingName.length() == 0){
session.setAttribute( "fail", "1" );
  response.sendRedirect("create.jsp");
}else if(mPwd.equals(mPwdre) == false){ // checking for passwords to match
session.setAttribute( "fail", "2" );
  response.sendRedirect("create.jsp");
}
else if(vPwd.equals(vPwdre) == false){ // checking for viewer passwords to match
  session.setAttribute( "fail", "2" );
  response.sendRedirect("create.jsp");
}else{
 out.println(" Valid! Saving to Redis!");

  // Here goes code when everything is VALID
  
  
  
   


}


%>