/**
 * deserialization.js — Insecure deserialization & XXE vulnerability examples (Node.js)
 *




 */

const vm = require('vm');

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badJSONParseUntrusted(userInput) {

    const data = JSON.parse(userInput);
    // Attacker: sends deeply nested JSON → DoS (stack overflow)
    // Attacker: {"__proto__": {"isAdmin": true}} — prototype pollution through JSON
    return data;
}

function badNodeSerializeDeserialize(userData) {

    // npm: node-serialize — known RCE gadget chain
    const serialize = require('node-serialize');
    const unserialized = serialize.unserialize(userData);
    // Attacker: {"rce":"_$$ND_FUNC$$_function(){require('child_process').exec('id')}()"}
    return unserialized;
}

function badJSEvalDeserialize(userInput) {

    const obj = eval('(' + userInput + ')');
    // Attacker: sends '({data: (function(){require("child_process").exec("id")})()})'
    return obj;
}

function badSerializeJS(userData) {

    const Serialize = require('serialize-javascript');
    // This library is for serialization only — deserializing with eval = RCE
    const serialized = Serialize(userData);
    const deserialized = eval('(' + serialized + ')');  // DANGER!
    return deserialized;
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badXMLParse(userXML) {

    const { parseString } = require('xml2js');
    // xml2js uses libxmljs under the hood which processes external entities by default
    parseString(userXML, (err, result) => {
        console.log(result);
    });
    // Attacker: <!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><data>&xxe;</data>
}

function badLibXMLParse(userXML) {

    const libxml = require('libxmljs');
    const xmlDoc = libxml.parseXml(userXML);  // External entities enabled by default!
    return xmlDoc.root().text();
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badDynamicRequire(moduleName) {

    const mod = require(moduleName);
    // Attacker: moduleName = 'child_process' → access to exec()
    // Attacker: moduleName = '../../../config/secrets' → path traversal
    return mod;
}

function badDynamicImport(userModule) {

    return import(userModule).then(mod => mod.default);
    // Attacker: userModule = 'fs' → file system access
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

function goodJSONParse(data, schema) {
    // Validate against schema before using
    const parsed = JSON.parse(data);

    // Simple schema validation
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
    // Use a safe XML parser that disables external entities by default
    // Modern Node.js: fast-xml-parser (default-safe)
    const { XMLParser } = require('fast-xml-parser');
    const parser = new XMLParser({
        allowBooleanAttributes: false,
        processEntities: false,  // Disable entity processing!
        stopNodes: ['*.pre', '*.code']  // Limit recursion
    });
    return parser.parse(userXML);
}

const SAFE_MODULES = new Set(['lodash', 'validator', 'moment']);
function goodDynamicRequire(moduleName) {
    // Whitelist approach: only allow known-safe modules
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
