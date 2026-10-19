// Flat-config excerpt. Spread `rules` into your eslint.config.js block.
export default {
  rules: {
    'no-restricted-imports': ['error', { patterns: [
      { group: ['lucide-react', 'lucide-*', 'lucide'], message: 'Use @phosphor-icons/react.' },
      { group: ['@fontsource/inter*', '@fontsource-variable/inter*', '@fontsource/geist*', '@fontsource-variable/geist*', 'geist', 'geist/*'], message: 'Use @cohen/tokens fonts.' },
    ]}],
    'no-restricted-syntax': ['error', { selector: "ImportDeclaration[source.value='next/font/google'] ImportSpecifier[imported.name=/^(Inter|Geist)/]", message: 'No Inter/Geist.' }],
  },
};
