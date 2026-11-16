import React, {createContext, useCallback, useContext, useEffect, useRef, useState} from 'react';
import {I18nManager, ScrollView, View, useWindowDimensions} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import type {LayoutChangeEvent, ViewStyle} from 'react-native';
import {onLayoutChange, platform} from '../native';
import type {Rect, WindowLayout} from '../native';

const initial: WindowLayout = {margins: {left: 18, right: 18}, regions: []};
const LayoutContext = createContext(initial);

export function WindowLayoutProvider({children}: {children: React.ReactNode}) {
  const [layout, setLayout] = useState(initial);
  useEffect(() => {
    let current = true;
    let received = false;
    const observer = onLayoutChange(update => {
      received = true;
      setLayout(update);
    });
    void platform('bootstrap').then(snapshot => {
      if (current && !received) {
        setLayout(snapshot.layout);
      }
    }).catch(() => {});
    return () => {
      current = false;
      observer.remove();
    };
  }, []);
  return <LayoutContext.Provider value={layout}>{children}</LayoutContext.Provider>;
}

export const useWindowLayout = () => useContext(LayoutContext);

function sameBounds(a: Rect | null, b: Rect) {
  return a && Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 &&
    Math.abs(a.width - b.width) < 0.5 && Math.abs(a.height - b.height) < 0.5;
}

export function useWindowBounds() {
  const {height, width} = useWindowDimensions();
  const {top, right, bottom, left} = useSafeAreaInsets();
  const ref = useRef<View>(null);
  const request = useRef(0);
  const [bounds, setBounds] = useState<Rect | null>(null);
  const measure = useCallback((_?: LayoutChangeEvent) => {
    const current = ++request.current;
    ref.current?.measureInWindow((x, y, w, h) => {
      if (current === request.current && w > 0 && h > 0) {
        const next = {x, y, width: w, height: h};
        setBounds(previous => sameBounds(previous, next) ? previous : next);
      }
    });
  }, []);
  useEffect(() => {
    measure();
    return () => { request.current += 1; };
  }, [measure, width, height, top, right, bottom, left]);
  return {ref, bounds, measure};
}

export function intersects(a: Rect, b: Rect) {
  return a.x < b.x + b.width && a.x + a.width > b.x &&
    a.y < b.y + b.height && a.y + a.height > b.y;
}

export function freeBand(bounds: Rect, slots: Rect[], start: number, end: number): [number, number] {
  const x1 = bounds.x + start;
  const x2 = bounds.x + bounds.width - end;
  const hits = slots.filter(slot => intersects(bounds, slot))
    .map(slot => [Math.max(x1, slot.x), Math.min(x2, slot.x + slot.width)] as const)
    .filter(([left, right]) => left < right)
    .sort((a, b) => a[0] - b[0]);
  const spaces: [number, number][] = [];
  let edge = x1;
  for (const [left, right] of hits) {
    if (left > edge) {
      spaces.push([edge, left]);
    }
    edge = Math.max(edge, right);
  }
  if (edge < x2) {
    spaces.push([edge, x2]);
  }
  const best = spaces.sort((a, b) =>
    (b[1] - b[0]) - (a[1] - a[0]) || (I18nManager.isRTL ? b[0] - a[0] : a[0] - b[0]))[0];
  return best ? [best[0] - bounds.x, bounds.x + bounds.width - best[1]] : [start, end];
}

export function ActionBand({children, minimumWidth = 152, style}: {
  children: React.ReactNode;
  minimumWidth?: number;
  style?: ViewStyle;
}) {
  const {ref, bounds, measure} = useWindowBounds();
  const layout = useWindowLayout();
  const center = bounds ? Math.max(0, (bounds.width - 760) / 2) : 0;
  const left = Math.max(layout.margins.left, center);
  const right = Math.max(layout.margins.right, center);
  const padding = bounds ? freeBand(bounds, layout.regions, left, right) : [left, right];
  const narrow = Boolean(bounds && bounds.width - padding[0] - padding[1] < minimumWidth);
  return (
    <View ref={ref} collapsable={false} onLayout={measure} style={style}>
      <View style={{paddingLeft: padding[0], paddingRight: padding[1]}}>
        {narrow ? (
          <ScrollView horizontal keyboardShouldPersistTaps="handled" directionalLockEnabled>
            <View style={{width: minimumWidth}}>{children}</View>
          </ScrollView>
        ) : children}
      </View>
    </View>
  );
}
