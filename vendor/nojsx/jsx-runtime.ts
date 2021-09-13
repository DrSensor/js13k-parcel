const { assign } = Object;

export const jsx = <
  T extends HTMLElementTagNameMap & SVGElementTagNameMap & FragmentMap,
>(
  tag: Exclude<keyof T, number | symbol>,
  props: Partial<T[typeof tag]> = {},
  ...children: (HTMLElement | SVGElement | DocumentFragment)[]
): T[typeof tag] => {
  const xmltag = tag.split(":"), [namespace$, tag$ = tag] = xmltag;
  html = namespace$ === "html" ? true : xmltag.includes("svg") ? false : html;

  const namespace = `http://www.w3.org/${html ? "1999/xhtml" : "2000/svg"}`,
    element = tag$
      ? document.createElementNS(namespace, tag$)
      : new DocumentFragment();

  assign(element, props).append(...children);
  return element as any;
};

let html = true;
export const Fragment = "";

declare global {
  namespace JSX {
    type IntrinsicElements = PartialProps<
      HTMLElementTagNameMap & SVGElementTagNameMap
    >;
  }
}

type FragmentMap = { "": DocumentFragment };
type PartialProps<NameMap> = {
  [Tag in keyof NameMap]: Partial<NameMap[Tag]>;
};
