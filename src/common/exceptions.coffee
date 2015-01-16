###* Adds nested exceptions.  

This would be used to indicate programmer error and 
not be reported to the end user.

https://www.joyent.com/developers/node/design/errors
###
class ErrorWithCause
    
    constructor: (@message, cause)->
        if cause?.message
            @message += "\tcaused by:\t#{cause.message}"
        
        stack = (new Error).stack
        if cause?.stack
            stack += "\tcaused by:\n\t#{cause.stack}"
        
        @stack = @message + "\n" + stack

    ErrorWithCause.throw = (message, cause)->
        throw new ErrorWithCause message, cause
    
###*
Localization separates values from the error message key.

Errors that may be reported to the end user.
###
class LocalizedException
    
    constructor: (@key, key_params=[], cause)->
        @message = @substitute_params key, key_params
        if cause?.message
            @message += "\tcaused by:\t#{cause.message}"
        
        stack = (new Error).stack
        if cause?.stack
            stack += "\tcaused by:\n\t#{cause.stack}"
        
        @stack = @message + "\n" + stack
    
    LocalizedException.throw = (key, key_params, cause)->
        throw new LocalizedException key, key_params, cause
        
    substitute_params:(key, params)->
        #get locale-*
        #for i in [0...params] by 1
        return key + JSON.stringify params
        
exports.LocalizedException = LocalizedException
exports.ErrorWithCause = ErrorWithCause