// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'jEAP',
  tagline: 'Java Enterprise Application Platform',
  favicon: 'img/favicon.ico',

  url: 'https://jeap-admin-ch.github.io',
  baseUrl: '/',

  organizationName: 'jeap-admin-ch',
  projectName: 'jeap-admin-ch.github.io',

  onBrokenLinks: 'throw',

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  themes: [
    '@docusaurus/theme-mermaid',
    // Offline / client-side search. Builds a search index at build time and
    // serves it statically — no external service, no API keys, works on
    // GitHub Pages. https://github.com/easyops-cn/docusaurus-search-local
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import('@easyops-cn/docusaurus-search-local').PluginOptions} */
      ({
        hashed: true,
        language: ['en'],
        indexDocs: true,
        indexBlog: false,
        indexPages: false,
        docsRouteBasePath: '/docs',
        highlightSearchTermsOnTargetPage: true,
        searchBarShortcut: true,
        searchBarPosition: 'auto',
      }),
    ],
  ],

  plugins: [
    // Generates llms.txt and llms-full.txt from the docs/ tree (llmstxt.org
    // standard) so AI agents can consume the documentation.
    // See https://docusaurus.io/community/resources#ai-agents
    [
      'docusaurus-plugin-llms',
      {
        generateLLMsTxt: true,
        generateLLMsFullTxt: true,
        generateMarkdownFiles: true,
        docsDir: 'docs',
        title: 'jEAP — Java Enterprise Application Platform',
        description:
          'Documentation for jEAP, the Java Enterprise Application Platform: reusable microservices, libraries, Spring Boot starters and tooling.',
      },
    ],
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarItemsGenerator: async function ({defaultSidebarItemsGenerator, ...args}) {
            return defaultSidebarItemsGenerator(args);
          },
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'jEAP',
        logo: {
          alt: 'jEAP Logo',
          src: 'img/logo.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'defaultSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://github.com/jeap-admin-ch',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {
                label: 'What is jEAP?',
                to: '/docs/what-is-jeap',
              },
              {
                label: 'Using jEAP',
                to: '/docs/using-jeap',
              }
            ],
          },
          {
            title: 'Building Blocks',
            items: [
              {
                label: 'Libraries',
                to: '/docs/building-blocks/libraries',
              },
              {
                label: 'Reusable Microservices',
                to: '/docs/building-blocks/reusable-microservices',
              },
              {
                label: 'Spring Boot Starters',
                to: '/docs/building-blocks/spring-boot-starters',
              },
              {
                label: 'Tooling & Registries',
                to: '/docs/building-blocks/tooling',
              }
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/jeap-admin-ch',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} jEAP. Apache 2 Licensed.`,
      },
    }),
};

export default config;
