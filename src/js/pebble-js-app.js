// Function to send a message to the Pebble using AppMessage API
var travel;

function sendMessage(msg) {
  Pebble.sendAppMessage({"0": msg});
}

//function sendURL(url) {
//  console.log(url);
//  Pebble.sendAppMessage({"1": url});
//}

Pebble.addEventListener("appmessage",
  function(e) {
    console.log("Received message: " +e.payload);
    
    if(e.payload.urlstring){
      
      console.log("e.payload.urlstring");
      var url = e.payload.urlstring;
      console.log(url);
      getText(url);
    }
    
    
    
  }
);


function getText(address){
  console.log("in get text function");
  //find a way to get article here, for now I will hard code it
  
  //address = "http://en.wikipedia.org/wiki/Heartbleed";
  
  var api_key = "f6687a0711a74306ac45cb89c08b026fe0cd03d6"; 
  var front_url = "http://access.alchemyapi.com/calls/url/URLGetText";
  var url = front_url + "?url=" + address + "&apikey=" + api_key + "&outputMode=json";
  //console.log("address: " + address);
  
  var req = new XMLHttpRequest();
  
  req.open('GET', url, true);
  req.onload = function(e) {
    
    if (req.status == 200){
        if(req.readyState==4) {
      //console.log("req.text: " + req.text);
      //console.log("JSON.parse(req.text) "); 
      var v = JSON.parse(req.responseText);
      //console.log("status: " + v.status);
      //console.log("text: " + v.text);
      //console.log("url: " + v.url);
      
      var my_article = v.text;
      //console.log("article_text " + my_article.substring(860,880));
      //console.log("article_text: " + my_article);
      
      var tempArticle = my_article; //redundant now but hard to fix
      var temp = tempArticle.split(" ");
      tempArticle = "";
      travel = 0;
      doSomething(temp, travel, travel+20);
      travel+=20;
      
      //console.log("tempArticle " + tempArticle);
      //sendMessage(tempArticle);
      return;
      //return "my article " + my_article;
    }
    else {
      //console.log("Error Getting Weather: " + req.status);
      sendMessage("ready state failed");
      return;
      //return "req.readyState failed: " + req.readyState;
    }
      //return "should never happen";
    }
  };
  req.send(null);
  
  //sendMessage("req failed");
  //return "req.status failed " + req.status;
}


function doSomething(temp, i, max) {
  
   if(i<temp.length && i<max){
        if(temp[i].length > 20){
          console.log("i: " + i + " temp[i]: " +temp[i]);
          temp[i] = "";
          travel+=1;
          doSomething(temp, i+1, max+1);
        } else if(temp[i].length > 13){
          sendMessage(temp[i].substring(0,7)+"-");
          sendMessage(temp[i].substring(7,temp[i].length));
          sleep(200);
          doSomething(temp, i+1, max);
        }
         else{
          console.log("temp[i]: " + temp[i]);
          sendMessage(temp[i]);
          sleep(200);
          doSomething(temp, i+1, max);
          //setTimeout(function(){}, 20000000);
        }
      //tempArticle=tempArticle+ " " + temp[i];
  }
   //do whatever you want here
}
function sleep(milliseconds) {
  var start = new Date().getTime();
  for (var i = 0; i < 1e7; i++) {
    if ((new Date().getTime() - start) > milliseconds){
      break;
    }
  }
}



// Called when JS is ready
Pebble.addEventListener("ready",
  function(e) {
    //sendURL("http://www.gizoogle.net");
    //getLocation(); 
    //getText("http://www.gizoogle.net");
  });
