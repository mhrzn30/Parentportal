const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        // CSS-only LWC modules have no .js file, so the lwc-jest resolver can't find them.
        '^c/portalTokens$':
            '<rootDir>/force-app/main/default/lwc/portalTokens/portalTokens.css'
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver']
};
