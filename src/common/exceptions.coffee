###* Adds nested exceptions ###
class ErrorWithCause extends Error

    constructor: (@message, @cause) ->
    
    ErrorWithCause.throw = (message, cause)->
        throw new ErrorWithCause(message, cause)
    
    ###
    get_stack_trace: ->
        str = ""
        if @cause
            if @cause.get_stack_trace
                str = @cause.get_stack_trace
            else
                if @cause.stack
                    str = @cause.stack
            str += "\n\n" unless str.length is 0
        
        str += @stack if @stack
        str
    ###
    
###* Localization separates values from the error message key ###
class LocalizedException extends ErrorWithCause

    constructor: (@key, @param_array=[], cause) ->
        #console.log 'cause',cause if cause
        super(@key, cause)
        
    LocalizedException.throw = (key, key_params, cause)->
        throw new LocalizedException(key, key_params, cause)
        
exports.LocalizedException = LocalizedException
exports.ErrorWithCause = ErrorWithCause