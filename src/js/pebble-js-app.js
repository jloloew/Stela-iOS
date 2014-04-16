// Function to send a message to the Pebble using AppMessage API
//var travel;
var words;

/*
function sendMessage(msg) {
  Pebble.sendAppMessage({"0": msg});
}*/

//function sendURL(url) {
//  console.log(url);
//  Pebble.sendAppMessage({"1": url});
//}

function sendEnd(){
  Pebble.sendAppMessage({2:"s"});
}

function sendWord (idx) {
  if (idx < words.length && idx < 10) {
    console.log("words[pos]: " + words[idx]);
    Pebble.sendAppMessage({0: words[idx]},
                           function () {
                             sendWord(idx + 1);
                           },
                           function () {
                             console.log("error - retrying...");
                             sendWord(idx);
                           }
      );

  } else{
      sendEnd();
  }
}

Pebble.addEventListener("appmessage",
  function(e) {
    //console.log("Received message: " +e.payload);
    
    if(e.payload.urlstring){
      var url = e.payload.urlstring;
      console.log(url);
      getText(url);
    }
    /*
    console.log("here1");
    if(e.payload.moreLetters){
      posReach = pos+5;
      console.log("here2");
      sendWord(pos);
    }
    */
    
    
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
      for(var i = 0; i<temp.length; i++){
        if(temp[i].length > 20){
          temp[i] = "";
        } else if(temp[i].length > 13){
          temp[i] = temp[i].substring(0,7) + "- " + temp[i].substring(7,temp[i].length);
        }
         else{
          //console.log("temp[i]: " + temp[i]);
          //sendMessage(temp[i]);
          //sleep(200);
          //doSomething(temp, i+1, max);
          //setTimeout(function(){}, 20000000);
        }
        //console.log("temp[i]: " + temp[i]);
      //tempArticle=tempArticle+ " " + temp[i];
      }
      words = temp;         
      sendWord(0);
      
      //doSomething(temp, travel, travel+30);
      //travel+=30;
      
      //console.log("tempArticle " + tempArticle);
      //sendMessage(tempArticle);
      //return "my article " + my_article;
    }
    else {
      //console.log("Error Getting Weather: " + req.status);
      //sendMessage("ready state failed");
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



// Called when JS is ready
Pebble.addEventListener("ready",
  function(e) {
    //sendURL("http://www.gizoogle.net");
    //getLocation(); 
    //getText("http://www.gizoogle.net");
  });
