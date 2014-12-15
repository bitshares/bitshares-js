###* Adds nested exceptions ###
class BetterError extends Error

    constructor: (message, fileName, lineNumber, @cause) ->
        super(message, fileName, lineNumber)
        
    get_stack_trace: ->
        str = ""
        if @cause
            if @cause.get_stack_trace
                str = @cause.get_stack_trace
            else
                if @cause.stack
                    str = @cause.stack
            str += "\n\n" unless str.length is 0
        
        str += super.stack if super.stack
    
###* Localization separates values from the error message key ###
class LocalizedException extends BetterError

    constructor: (@key, @param_array=[], cause) ->
        super(@key, cause)
        
    LocalizedException.throw = (key, key_params, cause)->
        throw new LocalizedException(key, key_params, cause)
        
exports.LocalizedException = LocalizedException