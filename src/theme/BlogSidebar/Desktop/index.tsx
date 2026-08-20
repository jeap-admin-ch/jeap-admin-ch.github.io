/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Swizzled to add RSS/Atom feed subscription links below the recent-posts list, so they are
// visible directly on the blog pages (not just in the site footer).

import React, {memo} from 'react';
import clsx from 'clsx';
import {translate} from '@docusaurus/Translate';
import {
  useVisibleBlogSidebarItems,
  BlogSidebarItemList,
} from '@docusaurus/plugin-content-blog/client';
import useBaseUrl from '@docusaurus/useBaseUrl';
import BlogSidebarContent from '@theme/BlogSidebar/Content';
import type {Props as BlogSidebarContentProps} from '@theme/BlogSidebar/Content';
import type {Props} from '@theme/BlogSidebar/Desktop';

import styles from './styles.module.css';

const ListComponent: BlogSidebarContentProps['ListComponent'] = ({items}) => {
  return (
    <BlogSidebarItemList
      items={items}
      ulClassName={clsx(styles.sidebarItemList, 'clean-list')}
      liClassName={styles.sidebarItem}
      linkClassName={styles.sidebarItemLink}
      linkActiveClassName={styles.sidebarItemLinkActive}
    />
  );
};

function BlogSidebarDesktop({sidebar}: Props) {
  const items = useVisibleBlogSidebarItems(sidebar.items);
  const rssUrl = useBaseUrl('/blog/rss.xml');
  const atomUrl = useBaseUrl('/blog/atom.xml');
  return (
    <aside className="col col--3">
      <nav
        className={clsx(styles.sidebar, 'thin-scrollbar')}
        aria-label={translate({
          id: 'theme.blog.sidebar.navAriaLabel',
          message: 'Blog recent posts navigation',
          description: 'The ARIA label for recent posts in the blog sidebar',
        })}>
        <div className={clsx(styles.sidebarItemTitle, 'margin-bottom--md')}>
          {sidebar.title}
        </div>
        <BlogSidebarContent
          items={items}
          ListComponent={ListComponent}
          yearGroupHeadingClassName={styles.yearGroupHeading}
        />
        <div className={clsx(styles.sidebarItemTitle, 'margin-bottom--sm', 'margin-top--md')}>
          Subscribe
        </div>
        <ul className={clsx(styles.sidebarItemList, 'clean-list')}>
          <li className={styles.sidebarItem}>
            <a
              className={styles.sidebarItemLink}
              href={rssUrl}>
              RSS
            </a>
          </li>
          <li className={styles.sidebarItem}>
            <a
              className={styles.sidebarItemLink}
              href={atomUrl}>
              Atom
            </a>
          </li>
        </ul>
      </nav>
    </aside>
  );
}

export default memo(BlogSidebarDesktop);
