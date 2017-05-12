/**
*
* Elasticsearch Cachebox Provider
* 
* @package cbElasticsearch.models.Cache
* @author Jon Clausen <jclausen@ortussolutions.com>
* @license Apache v2.0 <http://www.apache.org/licenses/>
* 
**/
component 
	name="ElasticsearchProvider" 
	serializable="false" 
	implements="coldbox.system.cache.ICacheProvider" 
	accessors=true
{
	/**
    * Constructor
    **/
	function init() {
		//Store our clients at the application level to prevent re-creation since Wirebox scoping may or may not be available
		if( !structKeyExists( application, "ElasticsearchProvider" ) ) application[ "ElasticsearchProvider" ] = {};
		// prepare instance data
		instance = {
			// provider name
			name 				= "",
			// provider version
			version				= "1.0",
			// provider enable flag
			enabled 			= false,
			// reporting enabled flag
			reportingEnabled 	= false,
			// configuration structure
			configuration 		= {},
			// cacheFactory composition
			cacheFactory 		= "",
			// event manager composition
			eventManager		= "",
			// storage composition, even if it does not exist, depends on cache
			store				= "",
			// the cache identifier for this provider
			cacheID				= createObject('java','java.lang.System').identityHashCode( this ),
			// Element Cleaner Helper
			elementCleaner		= CreateObject("component","coldbox.system.cache.util.ElementCleaner").init( this ),
			// Utilities
			utility				= createObject("component","coldbox.system.core.util.Util"),
			// our UUID creation helper
			uuidHelper			= createobject("java", "java.util.UUID"),
			// Java URI class
			URIClass 			= createObject("java", "java.net.URI"),
			// Java Time Units
			timeUnitClass 		= createObject("java", "java.util.concurrent.TimeUnit"),
			// For serialization of complex values
			converter			= createObject("component","coldbox.system.core.conversion.ObjectMarshaller").init(),
			// Java System for Debug Messages
			JavaSystem 			= createObject("java","java.lang.System"),
			// Javaloader ID placeholder
			javaLoaderID		= "",
			// The design document which tracks our keys in use
			designDocumentName = 'CacheBox_allKeys'
		};

		// JavaLoader Static ID
		instance.javaLoaderID 		= "cbElasticsearch-#instance.version#-loader";
		
		// Provider Property Defaults
		instance.DEFAULTS = {
			maxConnections = 10
			,defaultTimeoutUnit = "MINUTES"
			,objectDefaultTimeout = 30
            ,opQueueMaxBlockTime = 5000
	        ,opTimeout = 5000
	        ,timeoutExceptionThreshold = 5000
	        ,ignoreElasticsearchTimeouts = true
			,index = "escache-default"
			,type = "escache-objects"
			,server = "localhost:9200" // This can be an array
			,password = ""
			,caseSensitiveKeys : true
			,debug : false
			,updateStats : true
			,dbIndex = 0
		};		
		
		return this;
	}

	/**
	* Client provider for serialization operations
	**/
	Client function getClient() provider="Client@cbElasticsearch"{}
	
	/**
	* Elasticsearch Document provider
	**/
	Client function newDocument() provider="Document@cbElasticsearch"{}

	
	/**
    * get the cache name
    */    
	any function getName() output="false" {
		return instance.name;
	}
	
	/**
    * get the cache provider version
    */    
	any function getVersion() output="false" {
		return instance.version;
	}
	
	/**
    * set the cache name
    */    
	void function setName(required name) output="false" {
		instance.name = arguments.name;
	}
	
	/**
    * set the event manager
    */
    void function setEventManager(required any EventManager) output="false" {
    	instance.eventManager = arguments.eventManager;
    }
	
    /**
    * get the event manager
    */
    any function getEventManager() output="false" {
    	return instance.eventManager;
    }
    
	/**
    * get the cache configuration structure
    */
    any function getConfiguration() output="false" {
		return instance.config;
	}
	
	/**
    * set the cache configuration structure
    */
    void function setConfiguration(required any configuration) output="false" {
		instance.config = arguments.configuration;
	}
	
	/**
    * get the associated cache factory
    */
    any function getCacheFactory() output="false" {
		return instance.cacheFactory;
	}
		
	/**
    * set the associated cache factory
    */
    void function setCacheFactory(required any cacheFactory) output="false" {
		instance.cacheFactory = arguments.cacheFactory;
	}

	/**
    * configure the cache for operation
    */
    void function configure() output="false" {

		var config 	= getConfiguration();
		var props	= [];
		var URIs 	= [];
    	var i = 0;
		
		// Prepare the logger
		instance.logger = getCacheFactory().getLogBox().getLogger( this );
		instance.logger.debug("Starting up Provider Cache: #getName()# with configuration: #config.toString()#");
		
		// Validate the configuration
		validateConfiguration();

		// enabled cache
		instance.enabled = true;
		instance.reportingEnabled = true;
		instance.logger.info("Cache #getName()# started up successfully");
		
	}
	
	/**
    * shutdown the cache
    */
    void function shutdown() output="false" {
    	instance.logger.info("Provider Cache: #getName()# has been shutdown.");
	}
	
	/*
	* Indicates if cache is ready for operation
	*/
	any function isEnabled() output="false" {
		return instance.enabled;
	} 

	/*
	* Indicates if cache is ready for reporting
	*/
	any function isReportingEnabled() output="false" {
		return instance.reportingEnabled;
	}
	
	/*
	* Get the cache statistics object as coldbox.system.cache.util.ICacheStats
	* @colddoc:generic coldbox.system.cache.util.ICacheStats
	*/
	any function getStats() output="false" {
		// Not yet implmented		
	}
	
	/**
    * clear the cache stats: 
    */
    void function clearStatistics() output="false" {
    	// Not yet implemented
	}
	
	/**
    * Returns the underlying cache engine represented by the module ElasticSearch client
    */
    any function getObjectStore() output="false" {
    	// This provider uses an external object store
    	return getClient();
	}
	
	/**
    * get the cache's metadata report
    * @tested
    */
    any function getStoreMetadataReport() output="false" {	
		var md 		= {};
		var keys 	= getKeys();
		var item	= "";
		for( item in keys ){
			md[ item ] = getCachedObjectMetadata( item );
		}
		
		return md;
	}
	
	/**
	* Get a key lookup structure where cachebox can build the report on. Ex: [timeout=timeout,lastAccessTimeout=idleTimeout].  It is a way for the visualizer to construct the columns correctly on the reports
	* @tested
	*/
	any function getStoreMetadataKeyMap() output="false"{
		var keyMap = {
				LastAccessed = "LastAccessed",
				isExpired = "isExpired",
				timeout = "timeout",
				lastAccessTimeout = "lastAccessTimeout",
				hits = "hits",
				created = "createddate"
			};
		return keymap;
	}
	
	/**
    * get all the keys in this provider
    * @tested
    */
    any function getKeys() output="false" {
    	
    	local.allView = get( instance.designDocumentName );

    	if( isNull( local.allView ) ){
    		local.allView = [];
    		set( instance.designDocumentName, local.allView );
    	} else if( !isArray( local.allView ) ){
    		writeDump(var="BAD FORMAT",top=1);
    		writeDump(var=local.allView);
    		abort;
    	}

    	return local.allView;

	}

	void function appendCacheKey( objectKey ){

		var result = get( instance.designDocumentName );

		if( !isNull( result ) && isArray( result ) ) {
			if( isArray( arguments.objectKey ) ){
				arrayAppend( result, arguments.objectKey, true );
			} else if( !arrayFind( result, arguments.objectKey ) ){
				arrayAppend( result, arguments.objectKey );
				set( instance.designDocumentName, result );
			}
		} else {
			set( instance.designDocumentName, [ arguments.objectKey ] );
		}

	}
	
	/**
    * get an object's cached metadata
    * @tested
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys )  arguments.objectKey = lcase( arguments.objectKey );
		
		// prepare stats return map
    	local.keyStats = {
			timeout = "",
			lastAccessed = "",
			timeExpires = "",
			isExpired = 0,
			isDirty = 0,
			isSimple = 1,
			createdDate = "",
			metadata = {},
			cas = "",
			dataAge = 0,
			// We don't track these two, but I need a dummy values
			// for the CacheBox item report.
			lastAccessTimeout = 0,
			hits = 0
		};

		var ElasticsearchClient = getClient();
    	var local.object = ElasticsearchClient.get( arguments.objectKey );
    	// item is no longer in cache, or it's not a JSON doc.  No metastats for us
    	if( !isNull( local.object ) ){
    		
    		// inflate our object from JSON
			local.inflatedElement = local.object.getMemento();
			local.stats = duplicate( local.inflatedElement );

			for( var key in local.keyStats ){
				if( structKeyExists( local.stats, key ) ) local.keyStats[ key ] = local.stats[ key ];
			}

    		// key_exptime
    		if( structKeyExists( local.stats, "key_exptime" ) and isNumeric( local.stats[ "key_exptime" ] ) ){
    			local.keyStats.timeExpires = dateAdd("s", local.stats[ "key_exptime" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) ); 
    		}
    		// key_last_modification_time
    		if( structKeyExists( local.stats, "key_last_modification_time" ) and isNumeric( local.stats[ "key_last_modification_time" ] ) ){
    			local.keyStats.lastAccessed = dateAdd("s", local.stats[ "key_last_modification_time" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) ); 
    		}
    		// state
    		if( structKeyExists( local.stats, "key_vb_state" ) ){
    			local.keyStats.isExpired = ( local.stats[ "key_vb_state" ] eq "active" ? false : true ); 
    		}
    		// dirty
			if( structKeyExists( local.stats, "key_is_dirty" ) ){
    			local.keyStats.isDirty = local.stats[ "key_is_dirty" ]; 
    		}
    		// data_age
			if( structKeyExists( local.stats, "key_data_age" ) ){
    			local.keyStats.dataAge = local.stats[ "key_data_age" ]; 
    		}
    		// cas
			if( structKeyExists( local.stats, "key_cas" ) ){
    			local.keyStats.cas = local.stats[ "key_cas" ]; 
    		}

			// Simple values like 123 might appear to be JSON, but not a struct
			if(!isStruct(local.inflatedElement)) {
	    		return local.keyStats;
			}
					
			// createdDate
			if( structKeyExists( local.inflatedElement, "createdDate" ) ){
	   			local.keyStats.createdDate = local.inflatedElement.createdDate;
			}
			// timeout
			if( structKeyExists( local.inflatedElement, "timeout" ) ){
	   			local.keyStats.timeout = local.inflatedElement.timeout;
			}
			// metadata
			if( structKeyExists( local.inflatedElement, "metadata" ) ){
	   			local.keyStats.metadata = local.inflatedElement.metadata;
			}
			// isSimple
			if( structKeyExists( local.inflatedElement, "isSimple" ) ){
	   			local.keyStats.isSimple = local.inflatedElement.isSimple;
			}
    	}		
		
    	
    	return local.keyStats;
	}
	
	/**
    * get an item from cache, returns null if not found.
    * @tested
    */
    any function get(required any objectKey) output="false" {
    	return getQuiet(argumentCollection=arguments);
	}
	
	/**
    * get an item silently from cache, no stats advised: Stats not available on Elasticsearch
    * @tested
    */
    any function getQuiet(required any objectKey) output="false" {
    	
    	// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		
		
		//try {
			var ElasticsearchClient = getObjectStore();

    		// local.object will always come back as a string
    		local.object = ElasticsearchClient.get( 
    											javacast( "string", arguments.objectKey ), 
    											getConfiguration().index, 
    											getConfiguration().type 
    											);
    		
			// item is no longer in cache, return null
			if( isNull( local.object ) ){
				return;
			}
						
			// inflate our object from JSON
			local.inflatedElement = local.object.getMemento();
			
			// Simple values like 123 might appear to be JSON, but not a struct
			if( !isStruct( local.inflatedElement ) ) {
				return local.object;
			}


			// Is simple or not?
			if( structKeyExists( local.inflatedElement, "isSimple" ) and local.inflatedElement.isSimple ){
				
				if( getConfiguration().updateStats ) updateObjectStats( arguments.objectKey, duplicate( local.inflatedElement ) );
				
				return local.inflatedElement.data;
			}

			// else we deserialize and return
			if( structKeyExists( local.inflatedElement, "data" ) ){

				local.inflatedElement.data = instance.converter.deserializeGeneric( binaryObject=local.inflatedElement.data );
				
				if( getConfiguration().updateStats ){
					updateObjectStats( arguments.objectKey, duplicate( local.inflatedElement ) );	
				} 	

				return local.inflatedElement.data;
			}

			// who knows what this is?
			return local.object;
		// }
		// catch(any e) {
			
		// 	if( isTimeoutException( e ) && getConfiguration().ignoreTimeouts ) {
		// 		// log it
		// 		instance.logger.error( "Elasticsearch timeout exception detected: #e.message# #e.detail#", e );
		// 		// Return nothing as though it wasn't even found in the cache
		// 		return;
		// 	}
			
		// 	// For any other type of exception, rethrow.
		// 	rethrow;
		// }
	}

	any function getMulti( 
		required array objectKeys
	){
		var ts = getTickCount();
		
		var results = {};
		
		var ElasticsearchClient = getClient();

		var documents = getClient().getMultiple( 
			arguments.objectKeys,
			getConfiguration().index,
			getConfiguration().type
		);

		for( var document in documents ){
		
			var entry = document.getMemento();
			
			if( !entry.isSimple ) entry.data = instance.converter.deserializeGeneric( binaryObject=entry.data );
			
			results[ document.getId() ] = entry.data;

		}

		var te = getTickCount();

		if( getConfiguration().debug ) instance.JavaSystem.out.printLn( "Elasticsearch getMulti() executed in #( te - ts )#ms" );

		return results;
	}
	
	/**
    * Checks if a value has expired
    */
    any function isExpired(required any objectKey) output="false" {

		return isNull( getClient().get( arguments.objectKey ) );
	
	}
	 
	/**
    * check if object in cache
    * @tested
    */
    any function lookup(required any objectKey) output="false" {

    	return ( isNull( get( objectKey ) ) ? false : true );
	
	}
	
	/**
    * check if object in cache with no stats: Stats not available on Elasticsearch
    * @tested
    */
    any function lookupQuiet(required any objectKey) output="false" {
		return lookup( arguments.objectKey );
	}
	
	/**
    * set an object in cache and returns an object future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function set(
    	required any objectKey,
		required any object,
		any timeout           = instance.config.objectDefaultTimeout,
		any lastAccessTimeout = 0, // Not in use for this provider
		any extra             = {}
	) output="false" {

    	var ts = getTickCount();

		var future = setQuiet( argumentCollection=arguments );
		
		//ColdBox events
		var iData = { 
			"cache"                        = this,
			"cacheObject"                  = arguments.object,
			"cacheObjectKey"               = arguments.objectKey,
			"cacheObjectTimeout"           = arguments.timeout,
			"cacheObjectLastAccessTimeout" = arguments.lastAccessTimeout,
			"ElasticsearchFuture"          = future
		};

		if( arguments.objectKey != instance.designDocumentName ) appendCacheKey( arguments.objectKey );

		getEventManager().processState( state="afterCacheElementInsert", interceptData=iData, async=true );

    	var te = getTickCount();

		if( getConfiguration().debug ) instance.JavaSystem.out.printLn( "Elasticsearch set( #objectKey# ) executed in #( te - ts )#ms" );

		return future;
	}

	/**
    * set an object in cache with no advising to events, returns a Elasticsearch future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function setQuiet(
	    required any objectKey,
		required any object,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, //Not in use for this provider
		any extra={}
	) output="false" {
		
		return persistToCache( arguments.objectKey, formatCacheObject( argumentCollection=arguments ) );
	}	


	/**
    * Set multiple items in to the cache
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
	any function setMulti( 
		required struct mapping,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, // Not in use for this provider
		any extra={}
	) output="false" {
	
		var ts = getTickCount();

		var documents = [];

		for( var key in arguments.mapping ){
			
			var document = newDocument().new(  
				getConfiguration().index,
				getConfiguration().type,
				formatCacheObject( arguments.mapping[ key ] )
			);

			document.setId( key );

			arrayAppend( documents, document );

		}
		
		var transactionResult = getClient().saveAll( documents );

		var te = getTickCount();
		
		if( getConfiguration().debug ) instance.JavaSystem.out.printLn( "Elasticsearch Cache Provider setMulti() executed in #( te - ts )#ms" );
		
		appendCacheKey( structKeyArray( arguments.mapping ) );
		
		return transactionResult;
	
	}

	any function formatCacheObject( 
		required any object,
		any timeout=instance.config.objectDefaultTimeout,
		any lastAccessTimeout=0, //Not in use for this provider
		any extra={}
	) output="false" {
		// create storage element
		var sElement = {
			"createdDate" = dateformat( now(), "mm/dd/yyyy") & " " & timeformat( now(), "full" ),
			"timeout" = arguments.timeout,
			"metadata" = ( !isNull(arguments.extra) && structKeyExists( arguments.extra, "metadata" ) ? arguments.extra.metadata : {} ),
			"isSimple" = isSimpleValue( arguments.object ),
			"data" = arguments.object,
			"hits" = 0
		};

		// Do we need to serialize incoming obj
		if( !sElement.isSimple ){
			sElement.data = instance.converter.serializeGeneric( sElement.data );
		}

		return sElement;
	}

	any function persistToCache( 
		required any objectKey,
		required any cacheObject,
		boolean replaceItem=false
		any extra
	) output="false" {

		if( !getConfiguration().caseSensitiveKeys )  arguments.objectKey = lcase( arguments.objectKey );	


		// Serialize element to JSON
		var document = newDocument().new( 
			getConfiguration().index,
			getConfiguration().type,
			cacheObject
		);

		document.setId( objectKey );

    	try {
    		
			var future = document.save();

		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreElasticsearchTimeouts) {
				// log it
				instance.logger.error( "Elasticsearch timeout exception detected: #e.message# #e.detail#", e );
				// return nothing
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
		
		return future;
	}

	void function updateObjectStats( required any objectKey, required any cacheObject ){
		
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );
		if( !structKeyExists( cacheObject, "hits" ) ) cacheObject[ "hits" ] = 0;

		cacheObject[ "lastAccessed" ] = dateformat( now(), "mm/dd/yyyy") & " " & timeformat( now(), "full" );
		cacheObject[ "hits" ]++;

		// Do we need to serialize incoming obj
		if( !cacheObject.isSimple && !isSimpleValue( cacheObject.data ) ){
			cacheObject.data = instance.converter.serializeGeneric( cacheObject.data );
		}

		persistToCache( arguments.objectKey, cacheObject , true );
	}	
	
	
		
	/**
    * get cache size
    * @tested
    */
    any function getSize() output="false" {
 		// Not implemented
	}
	
	/**
    * Not implemented by this cache
    * @tested
    */
    void function reap() output="false" {
		// Not implemented by this provider
	}
	
	/**
    * clear all elements from cache
    * @tested
    */
    void function clearAll() output="false" {
		
		// If flush is not enabled for this bucket, no error will be thrown.  The call will simply return and nothing will happen.
		// Be very careful calling this.  It is an intensive asynch operation and the cache won't receive any new items until the flush
		// is finished which might take a few minutes.
		var ElasticsearchClient = getObjectStore();

		ElasticsearchClient.deleteIndex( getConfiguration().index );		

		var iData = {
			cache			= this
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll", iData );
	}
	
	/**
    * clear an element from cache and returns the Elasticsearch java future
    * @tested
    */
    any function clear(required any objectKey) output="false" {
		// lower case the keys for case insensitivity
		if( !getConfiguration().caseSensitiveKeys ) arguments.objectKey = lcase( arguments.objectKey );

		//allow an array of keys to be passed for multi clear
		if( isArray( arguments.objectKey ) ) arguments.objectKey = arrayToList( objectKey );
		
		// Delete from Elasticsearch
		var ElasticsearchClient = getObjectStore();

		var document = newDocument().new( getConfiguration().index, getConfiguration().type );
		document.setId( arguments.objectKey );

		var future = ElasticsearchClient.delete( document );
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObjectKey 		= arguments.objectKey,
			ElasticsearchFuture		= future
		};		

		getEventManager().processState( state="afterCacheElementRemoved", interceptData=iData, async=true );
		
		return future;
	}
	
	/**
    * Clear with no advising to events and returns with the Elasticsearch java future
    * @tested
    */
    any function clearQuiet(required any objectKey) output="false" {
		// normal clear, not implemented by Elasticsearch
		return clear( arguments.objectKey );
	}
	
	/**
	* Clear by key snippet
	*/
	void function clearByKeySnippet(required keySnippet, regex=false, async=false) output="false" {

		var threadName = "clearByKeySnippet_#replace(instance.uuidHelper.randomUUID(),"-","","all")#";
		
		// Async? IF so, do checks
		if( arguments.async AND NOT instance.utility.inThread() ){
			thread name="#threadName#"{
				instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
			}
		}
		else{
			instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
		}
		
	}
	
	/**
    * Expiration not implemented by Elasticsearch so clears are issued
    * @tested
    */
    void function expireAll() output="false"{ 
		clearAll();
	}
	
	/**
    * Expiration not implemented by Elasticsearch so clear is issued
    * @tested
    */
    void function expireObject(required any objectKey) output="false"{
		clear( arguments.objectKey );
	}

	/************************************** PRIVATE *********************************************/
	
	/**
	* Validate the incoming configuration and make necessary defaults
	**/
	private void function validateConfiguration() output="false"{
		var cacheConfig = getConfiguration();
		var key			= "";
		
		// Validate configuration values, if they don't exist, then default them to DEFAULTS
		for(key in instance.DEFAULTS){
			if( !structKeyExists( cacheConfig, key) || ( !isBoolean(cacheConfig[ key ]) && isSimpleValue( cacheConfig[ key ] ) && !len( cacheConfig[ key ] ) ) ){
				cacheConfig[ key ] = instance.DEFAULTS[ key ];
			}
		}

		instance.designDocumentName &= "-" &  getName();

	}
	
	private boolean function isTimeoutException(required any exception){

    	return ( exception.type == 'io.searchbox.jest.TimeoutException' || exception.message == 'timeout' || exception.message == 'could not connect' );
	
	}
	
	/**
    * Deal with errors that came back from the cluster
    * rowErrors is an array of com.Elasticsearch.client.protocol.views.RowError
    */
    private any function handleRowErrors(message, rowErrors) {
    	local.detail = '';
    	for(local.error in arguments.rowErrors) {
    		local.detail &= local.error.getFrom();
    		local.detail &= local.error.getReason();
    	}
    	
    	// It appears that there is still a useful result even if errors were returned so
    	// we'll just log it and not interrupt the request by throwing.  
    	instance.logger.warn(arguments.message, local.detail);
    	//Throw(message=arguments.message, detail=local.detail);
    	
    	return this;
    }

}
