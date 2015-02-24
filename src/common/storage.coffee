
class Storage
    
    constructor:(@namespace = "default")->
        @local_storage = window?.localStorage ||
            # WARNING: node-localstorage may not be atomic
            # https://github.com/lmaccherone/node-localstorage/issues/6
            new (
                require('node-localstorage').LocalStorage
            ) './localstorage-bitsharesjs'
    
    getItem:(key)->
        @local_storage.getItem @namespace+'\t'+key
    
    setItem:(key, value)->
        @local_storage.setItem @namespace+'\t'+key, value
        return
    
    removeItem:(key)->
        @local_storage.removeItem @namespace+'\t'+key
        return
    
    length:()->
        @local_storage.length
    
    key:(index)->
        @local_storage.key index
    
    #clear:()->
    #    @local_storage.clear()
    #    return
    
exports.Storage = Storage