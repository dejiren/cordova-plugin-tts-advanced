/*
    Cordova Text-to-Speech Plugin
    https://github.com/vilic/cordova-plugin-tts
 
    by VILIC VANE
    https://github.com/vilic

    updated by SEBASTIAAN PASMA
    https://github.com/spasma
 
    MIT License
*/

#import <Cordova/CDV.h>
#import <Cordova/CDVAvailability.h>
#import "CDVTTS.h"

@implementation CDVTTS

- (void)pluginInitialize {
    synthesizer = [AVSpeechSynthesizer new];
    synthesizer.delegate = self;
    queue = 0;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
    if (queue == 0) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryAmbient
                      withOptions:audioSession.categoryOptions | AVAudioSessionCategoryOptionDuckOthers
                            error:nil];
        [audioSession setActive:YES withOptions:0 error:nil];
    }
    queue++;
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    queue = MAX(queue - 1, 0);
    if (queue == 0) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryAmbient
                      withOptions:audioSession.categoryOptions & ~AVAudioSessionCategoryOptionDuckOthers
                            error:nil];
        [audioSession setActive:YES withOptions: 0 error:nil];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer*)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance*)utterance {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    if (lastCallbackId) {
        [self.commandDelegate sendPluginResult:result callbackId:lastCallbackId];
        lastCallbackId = nil;
    } else {
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        callbackId = nil;
    }
    
    queue = MAX(queue - 1, 0);
    if (queue <= 0) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryAmbient
                      withOptions:audioSession.categoryOptions & ~AVAudioSessionCategoryOptionDuckOthers
                            error:nil];
        [audioSession setActive:YES withOptions: 0 error:nil];
    }
}

- (void)speak:(CDVInvokedUrlCommand*)command {
    if (callbackId) {
        lastCallbackId = callbackId;
    }

    callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* text = [options objectForKey:@"text"];
    NSString* voiceURI = [options objectForKey:@"voiceURI"];
    NSString* identifier = [options objectForKey:@"identifier"];
    NSString* locale = [options objectForKey:@"locale"];
    bool cancel = [[options objectForKey:@"cancel"] boolValue];
    double rate = [[options objectForKey:@"rate"] doubleValue];
    double pitch = [[options objectForKey:@"pitch"] doubleValue];
    double volume = [[options objectForKey:@"volume"] doubleValue];

    if (!rate) {
        rate = AVSpeechUtteranceDefaultSpeechRate;
        NSLog(@"TTS: No rate set, so we're using OS default: '%lf'", (double)rate);
    }
    if (!pitch) {
        pitch = 1.0;
    }
    if (!volume) {
        volume = 1.0;
    }
    if (cancel == true) {
        NSLog(@"TTS: Cancel any speaking TTS-voices!");
        [synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }

    AVSpeechUtterance* utterance = [[AVSpeechUtterance new] initWithString:text];

    if (identifier) { // TODO SP: use identifier for both Android & iOS
        voiceURI = identifier;
    }

    if (!voiceURI || (id)voiceURI == [NSNull null]) {
        NSString * defaultOSLocale = [[NSLocale preferredLanguages] firstObject];
        if (!locale) {
            // No local given, let's get default locale from OS
            locale = defaultOSLocale;
            NSLog(@"TTS: No locale given so use: %@", locale);
        } else {
            NSLog(@"TTS: locale set, so let's hope that '%@' is a valid locale", locale);
        }
        AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithLanguage:locale];
        NSLog(@"TTS: We have found a voice: Name: %@, Identifier: %@, Quality: %ld", voice.name, voice.identifier, (long)voice.quality);
        utterance.voice = voice;
    } else {
        utterance.voice = [AVSpeechSynthesisVoice voiceWithIdentifier:voiceURI];
        NSLog(@"TTS: Tried to get voice by VoiceURI, this is what we got: Name: %@, Identifier: %@, Quality: %ld", utterance.voice.name, utterance.voice.identifier, (long)utterance.voice.quality);
    }
    utterance.rate = rate;
    utterance.pitchMultiplier = pitch;
    utterance.volume = volume;
    [synthesizer speakUtterance:utterance];
}

- (void)stop:(CDVInvokedUrlCommand*)command {
    [synthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

- (void)checkLanguage:(CDVInvokedUrlCommand *)command {
    NSArray *voices = [AVSpeechSynthesisVoice speechVoices];
    NSString *languages = @"";
    for (id voiceName in voices) {
        languages = [languages stringByAppendingString:@","];
        languages = [languages stringByAppendingString:[voiceName valueForKey:@"language"]];
    }
    if ([languages hasPrefix:@","] && [languages length] > 1) {
        languages = [languages substringFromIndex:1];
    }

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:languages];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)getVoices:(CDVInvokedUrlCommand*)command {
    NSArray *allVoices = [AVSpeechSynthesisVoice speechVoices];
    NSMutableArray *res = [[NSMutableArray alloc] init];

    for (AVSpeechSynthesisVoice *voice in allVoices) {
        NSLog(@"TTS: Voice Name: %@, Identifier: %@, Quality: %ld", voice.name, voice.identifier, (long)voice.quality);
        NSDictionary *lang = @{@"language": voice.language, @"name": voice.name, @"identifier": voice.identifier, @"voiceURI": voice.identifier};
        [res addObject:lang];
    }

    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:res];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}
@end
