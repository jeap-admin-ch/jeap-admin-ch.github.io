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
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

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
                to: '/docs/intro',
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
