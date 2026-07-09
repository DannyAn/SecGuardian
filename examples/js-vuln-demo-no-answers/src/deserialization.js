
const vm = require('vm');





function badJSONParseUntrusted(userInput) {

    const data = JSON.parse(userInput);
    
    
    return data;
}

function badNodeSerializeDeserialize(userData) {

    
    const serialize = require('node-serialize');
    const unserialized = serialize.unserialize(userData);
    
    return unserialized;
}

function badJSEvalDeserialize(userInput) {

    const obj = eval('(' + userInput + ')');
    
    return obj;
}

function badSerializeJS(userData) {

    const Serialize = require('serialize-javascript');
    
    const serialized = Serialize(userData);
    const deserialized = eval('(' + serialized + ')');  
    return deserialized;
}





function badXMLParse(userXML) {

    const { parseString } = require('xml2js');
    
    parseString(userXML, (err, result) => {
        console.log(result);
    });
    
}

function badLibXMLParse(userXML) {

    const libxml = require('libxmljs');
    const xmlDoc = libxml.parseXml(userXML);  
    return xmlDoc.root().text();
}





function badDynamicRequire(moduleName) {

    const mod = require(moduleName);
    
    
    return mod;
}

function badDynamicImport(userModule) {

    return import(userModule).then(mod => mod.default);
    
}





function goodJSONParse(data, schema) {
    
    const parsed = JSON.parse(data);

    
    const allowedFields = schema.fields || [];
    const validated = {};
    for (const field of allowedFields) {
        if (parsed[field] !== undefined) {
            validated[field] = parsed[field];
        }
    }
    return validated;
}

function goodXMLParse(userXML) {
    
    
    const { XMLParser } = require('fast-xml-parser');
    const parser = new XMLParser({
        allowBooleanAttributes: false,
        processEntities: false,  
        stopNodes: ['*.pre', '*.code']  
    });
    return parser.parse(userXML);
}

const SAFE_MODULES = new Set(['lodash', 'validator', 'moment']);
function goodDynamicRequire(moduleName) {
    
    if (!SAFE_MODULES.has(moduleName)) {
        throw new Error(`Module "${moduleName}" is not in the allowed list`);
    }
    return require(moduleName);
}

module.exports = {
    badJSONParseUntrusted, badNodeSerializeDeserialize, badJSEvalDeserialize,
    badSerializeJS, badXMLParse, badLibXMLParse, badDynamicRequire, badDynamicImport,
    goodJSONParse, goodXMLParse, goodDynamicRequire
};
