###* Adds nested exceptions.  

This would be used to indicate programmer error and 
not be reported to the end user.

https://www.joyent.com/developers/node/design/errors
###
class ErrorWithCause
    
    constructor: (@message, cause)->
        stack = (new Error).stack
        if cause
            caused_by = if cause.stack then cause.stack else JSON.stringify cause
            @message += "\tcaused by:\n\t#{caused_by}"
        @message += '\n'+stack

    ErrorWithCause.throw = (message, cause)->
        throw new ErrorWithCause message, cause
    
###*
Localization separates values from the error message key.

Errors that may be reported to the end user.
###
class LocalizedException
    
    constructor: (@key, key_params=[], cause)->
        @message = @substitute_params key, key_params
        stack = (new Error).stack
        if cause
            caused_by = if cause.stack then cause.stack else JSON.stringify cause
            @message += "\tcaused by:\n\t#{caused_by}"
        @message += '\n'+stack
        #console.log JSON.stringify @,null,4
    
    LocalizedException.throw = (key, key_params, cause)->
        throw new LocalizedException key, key_params, cause
        
    substitute_params:(key, params)->
        #get locale-*
        #for i in [0...params] by 1
        return key + JSON.stringify params
        
exports.LocalizedException = LocalizedException
exports.ErrorWithCause = ErrorWithCause