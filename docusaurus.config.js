// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'jEAP',
  tagline: 'Java Enterprise Application Platform',
  favicon: 'img/favicon.ico',

  url: 'https://jeap-admin-ch.github.io',
  baseUrl: '/',

  headTags: process.env.NOINDEX
    ? [{ tagName: 'meta', attributes: { name: 'robots', content: 'noindex, nofollow' } }]
    : [],

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

  themes: ['@docusaurus/theme-mermaid'],

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
                label: 'Getting Started',
                to: '/docs/what-is-jeap',
              },
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
