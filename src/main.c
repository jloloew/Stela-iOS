#include <stdlib.h>
#include <string.h>
#include "pebble.h"
#include "pebble_fonts.h"

#define ACCEL_STEP_MS 30

static Window *window;
static TextLayer *display_text;
static TextLayer *connection_text;
Layer *window_layer;
bool menu = true;
static AppTimer *timer;
static char *rate_text;
static BitmapLayer *image_layer;
GBitmap *image;
GBitmap *font_banner; 
GBitmap *game_bg;

enum {MENU,BOOK,SETTINGS} frame;
const char* fonts[4] = {FONT_KEY_GOTHIC_28, FONT_KEY_GOTHIC_28_BOLD, FONT_KEY_ROBOTO_CONDENSED_21 };
GFont disp_font;
int text_x = -40;
int text_y = 70;
int font_id = 0;
int hold = 60;
int speed = 25;


static char* body_text[200]; 
int max_length = 12;
int head_char=0;
int space_pos = 0;
int tail_char=200-1;
bool end = false;
int push_x = 0;
///////////////

enum {
    MESSAGE_KEY = 0,
    URLString = 1
    
};

// Called when a message is received from PebbleKitJS
static void in_received_handler(DictionaryIterator *received, void *context) {
    
    Tuple *tuple;
    tuple = dict_read_first(received);
  
  if(tuple){
    if(tuple->key == 1){
      APP_LOG(APP_LOG_LEVEL_DEBUG, "in receive handler, tuple->value->cstring: %s", tuple->value->cstring);

      DictionaryIterator *iter;
      app_message_outbox_begin(&iter);
      APP_LOG(APP_LOG_LEVEL_DEBUG, "in receive handler, value: %s", "1");

      //Tuplet value = TupletCString(1, tuple->value->cstring);
    
      dict_write_cstring(iter, 1, tuple->value->cstring);
      
      //dict_write_tuplet(iter, &value);
      APP_LOG(APP_LOG_LEVEL_DEBUG, "in receive handler, value: %s", "2");

      app_message_outbox_send();
      APP_LOG(APP_LOG_LEVEL_DEBUG, "in receive handler, value: %s", "3");
    
    }
    if(tuple->key == 0){
      APP_LOG(APP_LOG_LEVEL_DEBUG, "Received Message: %s", tuple->value->cstring);

        strcat(*body_text, " ");
        strcat(*body_text, tuple->value->cstring);
    }
  }
  
    
    //Tuple *myTuple;
    //myTuple = dict_find(received, URLString);
}

 void out_sent_handler(DictionaryIterator *sent, void *context) {
   
   
   // outgoing message was delivered
 }


 void out_failed_handler(DictionaryIterator *failed, AppMessageResult reason, void *context) {
   // outgoing message failed
 }


 void in_dropped_handler(AppMessageResult reason, void *context) {
   // incoming message dropped
 }
/////////////////////////

static void getNextWord(char *string[200], char* word[30]){
  if(end){
    return;
  }
  if(word==NULL){
    //nothing this is stupid
  }
  
    int space_dex = -1;
    int length = strlen(*string);
    //finds index of next space if it exists, if not return done.
    int current_pos = 0;
    for(int i=0; i<length; i++){
      if((*string)[i]==' '){
        current_pos++;
        if(current_pos == space_pos+1){
           space_pos++;
           space_dex = i;
           //APP_LOG(APP_LOG_LEVEL_DEBUG,"space_dex = %u",space_dex);
           break;
        }
      }
    }
  *word = "";
  
  
   //APP_LOG(APP_LOG_LEVEL_DEBUG,"outside space_dex = %u",space_dex);
   if(space_dex== -1){ //tere are no spaces so return done.
     int move = 0;
     while((*string)[head_char]!='\0'){
       (*word)[move] = (*string)[head_char];
       move++;
       head_char++;
     }
     end = true;
       //APP_LOG(APP_LOG_LEVEL_DEBUG,"DONE");
      return;
   }
  
  
  
  for(int k=0; k<30; k++){
    (*word)[k] = '\0';
  }
  //char * next_word[30];
  //copies the word to next word
  int mov = 0;
  for(int j=head_char+1; j<space_dex; j++){
      (*word)[mov] = (*string)[j];
    //APP_LOG(APP_LOG_LEVEL_DEBUG,"mov: %u",mov);
    mov++;
  }
  APP_LOG(APP_LOG_LEVEL_DEBUG,*word);
  head_char = space_dex;
  //word = next_word;  
}
int getLength(char* word[30]){
  if(end){
    return 100;
  }
  int length =0;
  for(int i=0;i<30;i++){
    if((*word)[i]!='\0'){
      length++;
    }
  }
  return length;
}
static void redraw_text(){
  hold--;
  if(hold<0){
      GRect move_pos2 = (GRect) { .origin = { text_x, text_y }, .size = { 180, 180 } };
      char* word[30];
      getNextWord(body_text,word);
      int wordLength=0;
      if(end){
          hold = 1000000;
      }else{
        wordLength = getLength(word);
        hold = (125/speed) + (wordLength*4/speed);
        int shift_x = 0;
        if(wordLength<=2){
           shift_x = 1;
        }else
        if(wordLength <= 5){
          shift_x = 2;
        }else if(wordLength <= 8){
          shift_x = 3;
        }else if(wordLength <= 12){
          shift_x = 4;
        }else if(wordLength <= 14){
          shift_x = 5;
        }else if(wordLength <= 16){
          shift_x = 6;
        }else if(wordLength <= 20){
          shift_x = 7;
        }
        
        char crop[20] = "";
        for(int i=0; i<shift_x; i++){
          crop[i] = (*word)[i];
        }
        
        GSize size = graphics_text_layout_get_content_size(crop,disp_font,move_pos2,GTextOverflowModeTrailingEllipsis,GTextAlignmentCenter);	
        int16_t size_x = size.w;
        APP_LOG(APP_LOG_LEVEL_DEBUG,"shift_x = %i theSize = %i",shift_x,size_x);
        push_x = size_x/2;
        
      }
      //hold = 10;
      move_pos2 = (GRect) { .origin = { text_x+push_x, text_y }, .size = { 180, 180 } };
      text_layer_set_text(display_text,*word);
      
      text_layer_set_text(connection_text,"");
      
      layer_set_frame(text_layer_get_layer(display_text),move_pos2);
  }
}
static void timer_callback(void *data) {
  redraw_text();
  //animation actionEvent
  timer = app_timer_register(ACCEL_STEP_MS, timer_callback, NULL);
}



static void change_to_menu(){
   frame = MENU;
   text_layer_set_text(connection_text,"Waiting for Device..");
   text_layer_set_text(display_text,"");
  
   GRect move_pos2 = (GRect) { .origin = { -15, 105 }, .size = { 180, 180 } };
   layer_set_frame(text_layer_get_layer(display_text),move_pos2);
   GRect move_pos3 = (GRect) { .origin = { -15, 130 }, .size = { 180, 180 } };
   layer_set_frame(text_layer_get_layer(connection_text),move_pos3);
  
   GRect move_pos4 = (GRect) { .origin = {-18, -15 }, .size = { 180, 180 } };
   layer_set_frame(bitmap_layer_get_layer(image_layer),move_pos4);
  
   bitmap_layer_set_bitmap(image_layer, image);
   bitmap_layer_set_alignment(image_layer, GAlignCenter);
  
}

static void change_to_settings(){
   frame = SETTINGS;
   text_layer_set_text(connection_text,"");
   text_layer_set_text(display_text,"FONT");
   GRect move_pos2 = (GRect) { .origin = { text_x, text_y }, .size = { 180, 180 } };
   layer_set_frame(text_layer_get_layer(display_text),move_pos2);
   text_layer_set_font(display_text, disp_font);APP_LOG(APP_LOG_LEVEL_DEBUG,"I'm done bro");
   GRect move_pos4 = (GRect) { .origin = { -18, -80 }, .size = { 180, 180 } };
   layer_set_frame(bitmap_layer_get_layer(image_layer),move_pos4);
  
   bitmap_layer_set_bitmap(image_layer, font_banner);
   bitmap_layer_set_alignment(image_layer, GAlignCenter);
  
}

static void change_to_book(){
   frame = BOOK;
  
    if(font_id==0){
      text_x=-40;
      text_y=70;
    }else if(font_id ==1 ){
      text_x =-40;
      text_y=70;
    }else if(font_id==2){
      text_x =-40;
      text_y = 73;
    }
  
   layer_remove_from_parent(text_layer_get_layer(connection_text));
   //text_layer_set_text(connection_text,"");
   text_layer_set_text(display_text,"Starting..");
  
   GRect move_pos2 = (GRect) { .origin = { text_x, text_y }, .size = { 180, 180 } };
   layer_set_frame(text_layer_get_layer(display_text),move_pos2);
  /*
   GRect move_pos3 = (GRect) { .origin = { -15, 130 }, .size = { 180, 180 } };
   layer_set_frame(text_layer_get_layer(connection_text),move_pos3);
  */
   text_layer_set_font(connection_text, disp_font);
  
   GRect move_pos4 = (GRect) { .origin = { -18, 0 }, .size = { 180, 180 } };
   layer_set_frame(bitmap_layer_get_layer(image_layer),move_pos4);
   
   bitmap_layer_set_compositing_mode(image_layer, GCompOpClear);
  
   bitmap_layer_set_bitmap(image_layer, game_bg);
   bitmap_layer_set_alignment(image_layer, GAlignCenter);
  
   timer = app_timer_register(ACCEL_STEP_MS, timer_callback, NULL);
}


void up_click_handler(ClickRecognizerRef recognizer, void *context) {
  if(frame == MENU){
    change_to_settings();
  }else
  if(frame == SETTINGS){
    change_to_menu();
  }
}

void middle_click_handler(ClickRecognizerRef recognizer, void *context) {
  if(frame==MENU){
    change_to_book();
  }
  if(frame == SETTINGS){
      font_id++;
    if(font_id>2){
      font_id = 0;
    }
    if(font_id==0){
      text_x=-20;
      text_y=70;
    }else if(font_id ==1 ){
      text_x =-20;
      text_y=70;
    }else if(font_id==2){
      text_x =-20;
      text_y = 73;
    }
      
      disp_font = fonts_get_system_font(fonts[font_id]);
      GRect move_pos2 = (GRect) { .origin = { text_x, text_y }, .size = { 180, 180 } };
      layer_set_frame(text_layer_get_layer(display_text),move_pos2);
      text_layer_set_font(display_text, disp_font);
  }
}

void down_click_handler(ClickRecognizerRef recognizer, void *context) {
  if(frame == MENU){
    
    
  }
}

void back_click_handler(ClickRecognizerRef recognizer, void *context) {
  if(frame == BOOK){
    head_char = 0;
    space_pos = 0;
    end = false;
    hold = 10;
  }
}

void config_provider(void *context) {
  window_single_click_subscribe(BUTTON_ID_SELECT, middle_click_handler);
  window_single_click_subscribe(BUTTON_ID_UP, up_click_handler);
  window_single_click_subscribe(BUTTON_ID_DOWN, down_click_handler);
  window_single_click_subscribe(BUTTON_ID_BACK, back_click_handler);
}

static void init() {
  window = window_create();
  window_set_fullscreen(window, true);
  window_stack_push(window, true /* Animated */);
  window_set_click_config_provider(window, config_provider);
  window_layer = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(window_layer);
  
  display_text = text_layer_create(bounds);
  connection_text = text_layer_create(bounds);
  image_layer = bitmap_layer_create(bounds);
  
  image = gbitmap_create_with_resource(RESOURCE_ID_IMAGE_STELA_ICON);
  font_banner = gbitmap_create_with_resource(RESOURCE_ID_IMAGE_FONT_BANNER);
  game_bg = gbitmap_create_with_resource(RESOURCE_ID_IMAGE_GAME_PANE_BLACK);
  
  disp_font = fonts_get_system_font(fonts[0]);
  text_layer_set_font(display_text, disp_font);
  
  change_to_menu();
  
  app_message_register_inbox_received(in_received_handler); 
  app_message_register_inbox_dropped(in_dropped_handler);
  app_message_register_outbox_sent(out_sent_handler);
  app_message_register_outbox_failed(out_failed_handler);
  app_message_open(app_message_inbox_size_maximum(), app_message_outbox_size_maximum());

  text_layer_set_text_alignment(display_text, GTextAlignmentCenter);
  text_layer_set_text_alignment(connection_text, GTextAlignmentCenter);
  
  layer_add_child(window_layer, text_layer_get_layer(display_text));
  layer_add_child(window_layer, text_layer_get_layer(connection_text));
  layer_add_child(window_layer, bitmap_layer_get_layer(image_layer));
  
  *body_text = " Heres a good test a it him shit bitch fucker fuckity fuckfuck bastardly fuckalicious";
   
}

static void deinit() {
  gbitmap_destroy(image);
  gbitmap_destroy(game_bg);
 // gbitmap_destory(font_banner);
  bitmap_layer_destroy(image_layer);
  text_layer_destroy(display_text);
  text_layer_destroy(connection_text);
  window_destroy(window);
  
}

int main(void) {
  init();
  app_event_loop();
  deinit();
}