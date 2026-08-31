/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Swizzled to add RSS/Atom feed subscription links above the recent-posts list, so they are
// visible directly on the blog pages (not just in the site footer).

import React, {memo, type ReactNode} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import {
  useVisibleBlogSidebarItems,
  BlogSidebarItemList,
} from '@docusaurus/plugin-content-blog/client';
import {NavbarSecondaryMenuFiller} from '@docusaurus/theme-common';
import BlogSidebarContent from '@theme/BlogSidebar/Content';
import type {Props} from '@theme/BlogSidebar/Mobile';
import type {Props as BlogSidebarContentProps} from '@theme/BlogSidebar/Content';

import styles from './styles.module.css';

const ListComponent: BlogSidebarContentProps['ListComponent'] = ({items}) => {
  return (
    <BlogSidebarItemList
      items={items}
      ulClassName="menu__list"
      liClassName="menu__list-item"
      linkClassName="menu__link"
      linkActiveClassName="menu__link--active"
    />
  );
};

function BlogSidebarMobileSecondaryMenu({sidebar}: Props): ReactNode {
  const items = useVisibleBlogSidebarItems(sidebar.items);
  const rssUrl = useBaseUrl('/blog/rss.xml');
  const atomUrl = useBaseUrl('/blog/atom.xml');
  return (
    <>
      <ul className="menu__list">
        <li className="menu__list-item">
          <a className="menu__link" href={rssUrl}>
            Subscribe (RSS)
          </a>
        </li>
        <li className="menu__list-item">
          <a className="menu__link" href={atomUrl}>
            Subscribe (Atom)
          </a>
        </li>
      </ul>
      <BlogSidebarContent
        items={items}
        ListComponent={ListComponent}
        yearGroupHeadingClassName={styles.yearGroupHeading}
      />
    </>
  );
}

function BlogSidebarMobile(props: Props): ReactNode {
  return (
    <NavbarSecondaryMenuFiller
      component={BlogSidebarMobileSecondaryMenu}
      props={props}
    />
  );
}

export default memo(BlogSidebarMobile);
