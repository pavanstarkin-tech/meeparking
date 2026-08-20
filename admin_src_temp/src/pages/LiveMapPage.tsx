import React, { useEffect, useRef, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import {
  MapPin,
  Search,
  Phone,
  MessageSquare,
  Zap,
  Navigation,
  PhoneCall,
  PhoneOff,
  Send,
  Boxes,
  RotateCw,
  X,
  Layers,
  Compass,
} from 'lucide-react';
import { Modal } from '../components/common/Modal';
import { FirebaseAdminService } from '../services/firebaseService';
import { ParkingSpace, UserProfile } from '../types';
import { decryptSecret } from '../utils/security';

const MAPBOX_TOKEN =
  (import.meta as any).env?.VITE_MAPBOX_ACCESS_TOKEN ||
  decryptSecret("3d2e6b3a290b630223212e3c14037106650540521a742d3c3e0f61121e7f72163a322a066179047f200b31113e2263287a14373b0707283b75574b572308703d627420057b14363c3d262a39631e7e457c20770866332a78283e281d2016370853057d41");

mapboxgl.accessToken = MAPBOX_TOKEN;

// Generate a fallback polygon perimeter around center coordinates (45m - 75m wide)
const generateLotPolygon = (lng: number, lat: number, sqMeters: number = 300): number[][] => {
  const sideMeters = Math.max(45, Math.min(80, Math.sqrt(Math.max(600, sqMeters * 4))));
  const latOffset = (sideMeters / 2) / 111000;
  const lngOffset = (sideMeters / 2) / (111000 * Math.cos((lat * Math.PI) / 180));

  return [
    [lng - lngOffset, lat - latOffset],
    [lng + lngOffset, lat - latOffset],
    [lng + lngOffset, lat + latOffset],
    [lng - lngOffset, lat + latOffset],
    [lng - lngOffset, lat - latOffset], // Close polygon
  ];
};

// Parse and normalize polygon coordinates to Mapbox GeoJSON standard [lng, lat]
const parseSpacePolygonGeoJSON = (space: ParkingSpace): number[][] => {
  if (space.polygonCoordinates && space.polygonCoordinates.length >= 3) {
    const pts: number[][] = space.polygonCoordinates.map((coord) => {
      const p0 = Number(coord[0]);
      const p1 = Number(coord[1]);

      // Firebase stores points as [lat, lng] from Flutter
      // Mapbox GeoJSON requires [lng, lat]
      let lat = p0;
      let lng = p1;

      // In Indian coordinates (and global standard):
      // If |p0| > 90, p0 was already longitude
      if (Math.abs(p0) > 90) {
        lng = p0;
        lat = p1;
      }

      return [lng, lat];
    });

    // Ensure the linear ring is closed (first point === last point)
    if (
      pts.length > 0 &&
      (pts[0][0] !== pts[pts.length - 1][0] || pts[0][1] !== pts[pts.length - 1][1])
    ) {
      pts.push([pts[0][0], pts[0][1]]);
    }
    return pts;
  }

  // Fallback if no custom polygon boundary is defined
  const lat = Number(space.latitude);
  const lng = Number(space.longitude);
  return generateLotPolygon(lng, lat, space.totalLandSqMeters || 300);
};

// Calculate geographic center of polygon for precise marker pin placement
const getPolygonCenter = (coords: number[][]): { lng: number; lat: number } => {
  if (!coords || coords.length === 0) return { lng: 0, lat: 0 };
  let sumLng = 0;
  let sumLat = 0;
  const isClosed =
    coords.length > 1 &&
    coords[0][0] === coords[coords.length - 1][0] &&
    coords[0][1] === coords[coords.length - 1][1];
  const count = isClosed ? coords.length - 1 : coords.length;

  for (let i = 0; i < count; i++) {
    sumLng += coords[i][0];
    sumLat += coords[i][1];
  }
  return { lng: sumLng / count, lat: sumLat / count };
};

export const LiveMapPage: React.FC = () => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<mapboxgl.Map | null>(null);
  const markersRef = useRef<Record<string, { marker: mapboxgl.Marker; el: HTMLDivElement }>>({});
  const orbitIntervalRef = useRef<any>(null);

  const [spaces, setSpaces] = useState<ParkingSpace[]>([]);
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterEvOnly, setFilterEvOnly] = useState(false);
  const [is3DMode, setIs3DMode] = useState(true);
  const [isOrbiting, setIsOrbiting] = useState(false);
  const [mapStyle, setMapStyle] = useState<'streets' | 'light' | 'dark'>('streets');

  // Interactive Active Space State
  const [hoveredSpace, setHoveredSpace] = useState<ParkingSpace | null>(null);
  const [selectedSpace, setSelectedSpace] = useState<ParkingSpace | null>(null);
  const [isCardDismissed, setIsCardDismissed] = useState(false);

  // Call Modal state
  const [callModalSpace, setCallModalSpace] = useState<ParkingSpace | null>(null);
  const [isCalling, setIsCalling] = useState(false);
  const [callTimer, setCallTimer] = useState(0);

  // Chat Modal state
  const [chatModalSpace, setChatModalSpace] = useState<ParkingSpace | null>(null);
  const [chatMessages, setChatMessages] = useState<
    Array<{ sender: 'admin' | 'partner'; text: string; time: string }>
  >([
    { sender: 'partner', text: 'Hello Admin! All parking bays and 3D sensors are online.', time: '10:14 AM' },
    { sender: 'admin', text: '3D Extrusions verified on Mapbox telemetry.', time: '10:15 AM' },
  ]);
  const [newMessage, setNewMessage] = useState('');

  // 1. Subscribe to Live Spaces and Users from Firebase RTDB
  useEffect(() => {
    const unsubSpaces = FirebaseAdminService.subscribeParkingSpaces((data) => {
      setSpaces(data);
    });
    const unsubUsers = FirebaseAdminService.subscribeUsers((data) => {
      setUsers(data);
    });
    return () => {
      unsubSpaces();
      unsubUsers();
    };
  }, []);

  // 2. Helper to safely add 3D & boundary layers (matching Flutter app visual design)
  const ensure3DLayers = (map: mapboxgl.Map) => {
    // 3D City Buildings
    const layers = map.getStyle().layers;
    const labelLayerId = layers?.find(
      (layer) => layer.type === 'symbol' && layer.layout && (layer.layout as any)['text-field']
    )?.id;

    if (!map.getLayer('3d-buildings')) {
      map.addLayer(
        {
          id: '3d-buildings',
          source: 'composite',
          'source-layer': 'building',
          filter: ['==', 'extrude', 'true'],
          type: 'fill-extrusion',
          minzoom: 13,
          paint: {
            'fill-extrusion-color': '#cbd5e1',
            'fill-extrusion-height': [
              'interpolate',
              ['linear'],
              ['zoom'],
              13,
              0,
              15.05,
              ['get', 'height'],
            ],
            'fill-extrusion-base': [
              'interpolate',
              ['linear'],
              ['zoom'],
              13,
              0,
              15.05,
              ['get', 'min_height'],
            ],
            'fill-extrusion-opacity': 0.3,
          },
        },
        labelLayerId
      );
    }

    // Parking Lots GeoJSON Source
    if (!map.getSource('parking-lots-3d-source')) {
      map.addSource('parking-lots-3d-source', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      });
    }

    // Ground Highlight Layer (Base property boundary fill)
    if (!map.getLayer('parking-lots-ground-fill')) {
      map.addLayer({
        id: 'parking-lots-ground-fill',
        type: 'fill',
        source: 'parking-lots-3d-source',
        paint: {
          'fill-color': ['get', 'color'],
          'fill-opacity': ['get', 'fillOpacity'],
        },
      });
    }

    // Ground Perimeter Line Layer (Crisp boundary outline matching search_parking_screen)
    if (!map.getLayer('parking-lots-ground-line')) {
      map.addLayer({
        id: 'parking-lots-ground-line',
        type: 'line',
        source: 'parking-lots-3d-source',
        paint: {
          'line-color': ['get', 'borderColor'],
          'line-width': 3,
          'line-opacity': 0.95,
        },
      });
    }

    // 3D Extruded Building Layer (Low profile volumetric 3D footprint)
    if (!map.getLayer('parking-lots-3d-extrusion')) {
      map.addLayer({
        id: 'parking-lots-3d-extrusion',
        type: 'fill-extrusion',
        source: 'parking-lots-3d-source',
        paint: {
          'fill-extrusion-color': ['get', 'color'],
          'fill-extrusion-height': ['get', 'height'],
          'fill-extrusion-base': 0,
          'fill-extrusion-opacity': ['get', 'extrusionOpacity'],
        },
      });

      // Click on polygon area to select
      const handlePolygonClick = (e: mapboxgl.MapLayerMouseEvent) => {
        if (e.features && e.features[0]) {
          const spaceId = e.features[0].properties?.id;
          const found = spaces.find((s) => s.id === spaceId);
          if (found) {
            setSelectedSpace(found);
            setHoveredSpace(found);
            setIsCardDismissed(false);
          }
        }
      };

      map.on('click', 'parking-lots-3d-extrusion', handlePolygonClick);
      map.on('click', 'parking-lots-ground-fill', handlePolygonClick);
    }
  };

  // 3. Initialize Mapbox GL Map
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [77.5946, 12.9716],
      zoom: 15.5,
      pitch: 60, // 3D Isometric View
      bearing: -20,
    });

    map.addControl(new mapboxgl.NavigationControl({ visualizePitch: true }), 'bottom-right');

    map.on('style.load', () => {
      ensure3DLayers(map);
      syncMarkers(map, spaces);
      update3DLayerData(map, spaces, selectedSpace);
    });

    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, []);

  // Handle map style changes
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;
    const styleMap = {
      streets: 'mapbox://styles/mapbox/streets-v12',
      light: 'mapbox://styles/mapbox/light-v11',
      dark: 'mapbox://styles/mapbox/dark-v11',
    };
    map.setStyle(styleMap[mapStyle]);
  }, [mapStyle]);

  // 4. Create & Manage Persistent Markers (Positioned at polygon centroid)
  const syncMarkers = (map: mapboxgl.Map, currentSpaces: ParkingSpace[]) => {
    if (!map) return;

    const bounds = new mapboxgl.LngLatBounds();
    let hasValidCoords = false;

    // Track which ids exist in currentSpaces
    const currentIds = new Set(currentSpaces.map((s) => s.id));

    // Remove markers that no longer exist
    Object.keys(markersRef.current).forEach((id) => {
      if (!currentIds.has(id)) {
        markersRef.current[id].marker.remove();
        delete markersRef.current[id];
      }
    });

    // Add or retain markers
    currentSpaces.forEach((space) => {
      const polygonCoords = parseSpacePolygonGeoJSON(space);
      const center = getPolygonCenter(polygonCoords);
      const lat = center.lat || Number(space.latitude);
      const lng = center.lng || Number(space.longitude);

      if (isNaN(lat) || isNaN(lng) || (lat === 0 && lng === 0)) return;

      hasValidCoords = true;

      // Extend bounds using full polygon boundary points
      polygonCoords.forEach(([pLng, pLat]) => {
        if (!isNaN(pLng) && !isNaN(pLat) && pLng !== 0 && pLat !== 0) {
          bounds.extend([pLng, pLat]);
        }
      });

      // If marker already exists, update position
      if (markersRef.current[space.id]) {
        markersRef.current[space.id].marker.setLngLat([lng, lat]);
        return;
      }

      const el = document.createElement('div');
      el.className = 'mapbox-parking-marker-root';
      el.style.zIndex = '50';
      el.style.cursor = 'pointer';
      el.style.transformOrigin = 'bottom center';

      el.addEventListener('mouseenter', () => {
        setHoveredSpace(space);
        setIsCardDismissed(false);
      });

      el.addEventListener('click', (e) => {
        e.stopPropagation();
        setSelectedSpace(space);
        setHoveredSpace(space);
        setIsCardDismissed(false);
        map.flyTo({
          center: [lng, lat],
          zoom: 17,
          pitch: is3DMode ? 60 : 0,
          bearing: is3DMode ? -20 : 0,
          essential: true,
        });
      });

      const marker = new mapboxgl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([lng, lat])
        .addTo(map);

      markersRef.current[space.id] = { marker, el };
    });

    if (hasValidCoords && !bounds.isEmpty()) {
      map.fitBounds(bounds, { padding: 90, maxZoom: 16, duration: 1000 });
    }
  };

  // 5. Update Marker Visuals & Boundary Layer Data
  const updateVisuals = (
    map: mapboxgl.Map,
    currentSpaces: ParkingSpace[],
    activeSelected: ParkingSpace | null
  ) => {
    // 1. Update existing Marker DOMs directly
    currentSpaces.forEach((space) => {
      const entry = markersRef.current[space.id];
      if (!entry) return;

      const isOpened = activeSelected?.id === space.id && !isCardDismissed;
      const isHovered = hoveredSpace?.id === space.id && !isCardDismissed;
      const hasSlots = space.availableSlots > 0;

      // Color scheme: GREEN if opened, PURPLE if available, RED if full
      const plotColor = isOpened
        ? '#10B981'
        : hasSlots
        ? '#7C3AED'
        : '#EF4444';

      const badgeBg = isOpened ? '#059669' : hasSlots ? '#10B981' : '#F43F5E';

      const markerGradient = isOpened
        ? 'linear-gradient(135deg, #10B981, #059669)'
        : 'linear-gradient(135deg, #7C3AED, #4F46E5)';

      const markerShadow = isOpened
        ? '0 0 0 6px rgba(16, 185, 129, 0.4), 0 12px 30px rgba(16, 185, 129, 0.7)'
        : isHovered
        ? '0 0 0 4px rgba(124, 58, 237, 0.3), 0 10px 25px rgba(124, 58, 237, 0.6)'
        : '0 8px 24px rgba(124, 58, 237, 0.5)';

      const scale = isOpened ? 'scale(1.15)' : isHovered ? 'scale(1.1)' : 'scale(1)';

      entry.el.innerHTML = `
        <div style="position: relative; width: 48px; height: 56px; display: flex; flex-direction: column; align-items: center; transition: transform 0.2s ease; transform: ${scale};">
          <div style="background: ${markerGradient}; color: white; width: 42px; height: 42px; border-radius: 14px; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 15px; box-shadow: ${markerShadow}; border: 3px solid white;">
            P
          </div>
          <div style="position: absolute; top: -6px; right: -4px; background: ${badgeBg}; color: white; border-radius: 999px; font-size: 10px; font-weight: 800; padding: 2px 6px; border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
            ${space.availableSlots}
          </div>
          <div style="width: 0; height: 0; border-left: 7px solid transparent; border-right: 7px solid transparent; border-top: 9px solid ${plotColor}; margin-top: -1px;"></div>
        </div>
      `;
    });

    // 2. Update GeoJSON source with accurate property boundary polygons
    update3DLayerData(map, currentSpaces, activeSelected);
  };

  const update3DLayerData = (
    map: mapboxgl.Map,
    currentSpaces: ParkingSpace[],
    activeSelected: ParkingSpace | null
  ) => {
    if (!map || !map.isStyleLoaded()) return;

    ensure3DLayers(map);

    const features: GeoJSON.Feature[] = [];

    currentSpaces.forEach((space) => {
      const polygonCoords = parseSpacePolygonGeoJSON(space);
      const center = getPolygonCenter(polygonCoords);
      const lat = center.lat || Number(space.latitude);
      const lng = center.lng || Number(space.longitude);
      if (isNaN(lat) || isNaN(lng) || (lat === 0 && lng === 0)) return;

      const isOpened = activeSelected?.id === space.id && !isCardDismissed;
      const isHovered = hoveredSpace?.id === space.id && !isCardDismissed;
      const hasSlots = space.availableSlots > 0;

      // Color scheme matching Flutter app:
      // Purple fill/border for standard listings, Emerald for selected, Red for full
      const plotColor = isOpened
        ? '#10B981' // Green when opened
        : isHovered
        ? '#8B5CF6' // Light Purple on hover
        : hasSlots
        ? '#7C3AED' // Primary AppColors.primary
        : '#EF4444';

      const borderColor = isOpened
        ? '#059669'
        : isHovered
        ? '#7C3AED'
        : hasSlots
        ? '#6B2D9B'
        : '#DC2626';

      // Extrusion parameters
      const extrusionHeight = is3DMode ? (isOpened ? 12 : 7) : 0;
      const fillOpacity = isOpened ? 0.35 : 0.22;
      const extrusionOpacity = is3DMode ? (isOpened ? 0.55 : 0.35) : 0;

      features.push({
        type: 'Feature',
        properties: {
          id: space.id,
          title: space.title,
          color: plotColor,
          borderColor: borderColor,
          height: extrusionHeight,
          fillOpacity: fillOpacity,
          extrusionOpacity: extrusionOpacity,
        },
        geometry: {
          type: 'Polygon',
          coordinates: [polygonCoords],
        },
      });
    });

    const source = map.getSource('parking-lots-3d-source') as mapboxgl.GeoJSONSource;
    if (source) {
      source.setData({
        type: 'FeatureCollection',
        features,
      });
    }
  };

  // Synchronize when spaces change
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (map) {
      if (map.isStyleLoaded()) {
        syncMarkers(map, spaces);
        updateVisuals(map, spaces, selectedSpace);
      } else {
        map.once('style.load', () => {
          syncMarkers(map, spaces);
          updateVisuals(map, spaces, selectedSpace);
        });
      }
    }
  }, [spaces]);

  // Synchronize visuals when selection or hover changes (instant, no marker destruction)
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (map && map.isStyleLoaded()) {
      updateVisuals(map, spaces, selectedSpace);
    }
  }, [selectedSpace, hoveredSpace, isCardDismissed]);

  // 3D Camera Orbit Animation Toggle
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    if (isOrbiting) {
      orbitIntervalRef.current = setInterval(() => {
        const currentBearing = map.getBearing();
        map.rotateTo(currentBearing + 1, { duration: 100 });
      }, 100);
    } else {
      if (orbitIntervalRef.current) clearInterval(orbitIntervalRef.current);
    }

    return () => {
      if (orbitIntervalRef.current) clearInterval(orbitIntervalRef.current);
    };
  }, [isOrbiting]);

  // Toggle 3D vs 2D Perspective
  const handleToggle3D = () => {
    const map = mapInstanceRef.current;
    if (!map) return;
    const nextMode = !is3DMode;
    setIs3DMode(nextMode);

    map.easeTo({
      pitch: nextMode ? 60 : 0,
      bearing: nextMode ? -25 : 0,
      duration: 1000,
    });
  };

  // Call Timer
  useEffect(() => {
    let interval: any;
    if (isCalling) {
      interval = setInterval(() => setCallTimer((prev) => prev + 1), 1000);
    } else {
      setCallTimer(0);
    }
    return () => clearInterval(interval);
  }, [isCalling]);

  const formatTimer = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const getPartnerInfo = (ownerId: string) => {
    const partner = users.find((u) => u.uid === ownerId);
    return {
      name: partner?.businessName || partner?.name || 'Space Manager',
      phone: partner?.phone || '+91 98765 43210',
      email: partner?.email || 'partner@meeparking.com',
    };
  };

  const filteredSpaces = spaces.filter((s) => {
    const query = searchQuery.toLowerCase().trim();
    const matchesQuery =
      s.title.toLowerCase().includes(query) ||
      s.address.toLowerCase().includes(query) ||
      s.id.toLowerCase().includes(query);
    const matchesEv = !filterEvOnly || s.isEvCharging;
    return matchesQuery && matchesEv;
  });

  const handleFlyToSpace = (space: ParkingSpace) => {
    setSelectedSpace(space);
    setHoveredSpace(space);
    setIsCardDismissed(false);
    const map = mapInstanceRef.current;
    const polygonCoords = parseSpacePolygonGeoJSON(space);
    const center = getPolygonCenter(polygonCoords);
    const lat = center.lat || Number(space.latitude);
    const lng = center.lng || Number(space.longitude);
    if (map && !isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0) {
      map.flyTo({
        center: [lng, lat],
        zoom: 17,
        pitch: is3DMode ? 60 : 0,
        bearing: is3DMode ? -20 : 0,
        essential: true,
      });
    }
  };

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim()) return;
    setChatMessages((prev) => [
      ...prev,
      {
        sender: 'admin',
        text: newMessage,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      },
    ]);
    setNewMessage('');
  };

  // Active space to display in details card (only when hovered or selected, and NOT closed)
  const activeSpace = !isCardDismissed ? (hoveredSpace || selectedSpace) : null;
  const activePartner = activeSpace ? getPartnerInfo(activeSpace.ownerId) : null;

  return (
    <div className="relative h-[calc(100vh-8.5rem)] rounded-2xl overflow-hidden border border-slate-200 shadow-sm flex">
      {/* 1. Left Interactive Drawer: Space Search & List */}
      <div className="w-80 bg-white border-r border-slate-200 flex flex-col z-10 shrink-0">
        {/* Header */}
        <div className="p-4 border-b border-slate-100 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="font-extrabold text-sm text-slate-900 flex items-center gap-2">
              <Boxes className="w-4 h-4 text-purple-600" />
              3D Parking Radar ({spaces.length})
            </h3>
            <span className="text-[10px] font-bold bg-purple-50 text-purple-700 px-2 py-0.5 rounded-full border border-purple-200 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-purple-600 animate-pulse" /> 3D Extruded
            </span>
          </div>

          <div className="relative">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search 3D spots by location..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-9 pr-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:border-purple-500"
            />
          </div>

          {/* 3D Camera Controls Bar */}
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={handleToggle3D}
              className={`py-1.5 px-2 rounded-xl text-[11px] font-bold flex items-center justify-center gap-1.5 border transition-all ${
                is3DMode
                  ? 'bg-purple-600 text-white border-purple-600 shadow-sm'
                  : 'bg-slate-50 text-slate-600 border-slate-200'
              }`}
            >
              <Boxes className="w-3.5 h-3.5" />
              {is3DMode ? '3D Isometric' : '2D Flat Map'}
            </button>

            <button
              onClick={() => setIsOrbiting(!isOrbiting)}
              className={`py-1.5 px-2 rounded-xl text-[11px] font-bold flex items-center justify-center gap-1.5 border transition-all ${
                isOrbiting
                  ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm'
                  : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100'
              }`}
            >
              <RotateCw className={`w-3.5 h-3.5 ${isOrbiting ? 'animate-spin' : ''}`} />
              {isOrbiting ? 'Orbiting 3D' : 'Orbit Camera'}
            </button>
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => setFilterEvOnly(!filterEvOnly)}
              className={`flex-1 py-1.5 px-2 rounded-xl text-[11px] font-bold flex items-center justify-center gap-1 border transition-all ${
                filterEvOnly
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-300'
                  : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100'
              }`}
            >
              <Zap className={`w-3 h-3 ${filterEvOnly ? 'fill-emerald-600 text-emerald-600' : 'text-slate-400'}`} />
              EV Charging Only
            </button>

            {/* Map Style Selector */}
            <select
              value={mapStyle}
              onChange={(e) => setMapStyle(e.target.value as any)}
              className="bg-slate-50 border border-slate-200 rounded-xl px-2 py-1 text-[11px] font-bold text-slate-700 focus:outline-none"
            >
              <option value="streets">Streets</option>
              <option value="light">Light</option>
              <option value="dark">Dark 3D</option>
            </select>
          </div>
        </div>

        {/* Spots Scroll List */}
        <div className="flex-1 overflow-y-auto divide-y divide-slate-100 p-2 space-y-1">
          {filteredSpaces.map((space) => {
            const isSelected = (selectedSpace?.id === space.id || hoveredSpace?.id === space.id) && !isCardDismissed;
            const hasSlots = space.availableSlots > 0;

            return (
              <div
                key={space.id}
                onClick={() => handleFlyToSpace(space)}
                onMouseEnter={() => {
                  setHoveredSpace(space);
                  setIsCardDismissed(false);
                }}
                className={`p-3 rounded-xl cursor-pointer transition-all duration-150 border ${
                  isSelected
                    ? 'bg-emerald-50/90 border-emerald-300 shadow-sm'
                    : 'bg-white border-transparent hover:bg-slate-50'
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <h4 className="font-bold text-xs text-slate-900 line-clamp-1">{space.title}</h4>
                  <span
                    className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full shrink-0 ${
                      isSelected
                        ? 'bg-emerald-600 text-white'
                        : hasSlots
                        ? 'bg-emerald-100 text-emerald-700'
                        : 'bg-rose-100 text-rose-700'
                    }`}
                  >
                    {space.availableSlots}/{space.totalSlots} Free
                  </span>
                </div>

                <p className="text-[11px] text-slate-400 line-clamp-1 mt-1 flex items-center gap-1">
                  <MapPin className="w-3 h-3 text-slate-300 shrink-0" />
                  {space.address}
                </p>

                <div className="mt-2 flex items-center justify-between text-[11px] pt-1.5 border-t border-slate-100/60">
                  <span className="font-extrabold text-purple-700">₹{space.pricing.hourly}/hr</span>
                  <span className="text-[10px] font-bold text-emerald-600 flex items-center gap-1">
                    <Boxes className="w-3 h-3" /> 3D Area: {space.totalLandSqMeters || 150}m²
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* 2. Central Full-Screen Mapbox 3D Canvas */}
      <div
        className="flex-1 h-full relative"
        onClick={() => {
          setSelectedSpace(null);
          setHoveredSpace(null);
          setIsCardDismissed(true);
        }}
      >
        <div ref={mapContainerRef} className="w-full h-full" />

        {/* 3D Mode Floating Indicator Badge */}
        <div className="absolute top-4 left-4 z-20 bg-slate-900/80 backdrop-blur-md text-white px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-2 border border-slate-700 shadow-lg pointer-events-none">
          <Boxes className="w-4 h-4 text-purple-400 animate-pulse" />
          <span>3D Extruded Listings Active</span>
        </div>

        {/* 3. Floating Slot Details Card on Hover / Selection (Top-Right Overlay with CLOSE 'X' BUTTON) */}
        {activeSpace && activePartner && (
          <div
            onClick={(e) => e.stopPropagation()}
            onMouseEnter={() => setIsCardDismissed(false)}
            className="absolute top-4 right-4 z-30 w-88 max-w-sm bg-white/95 backdrop-blur-md rounded-2xl p-5 border border-purple-100 shadow-2xl space-y-4 animate-in fade-in zoom-in-95 duration-150"
          >
            {/* Header with thumbnail & Close X Button */}
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-start gap-3 min-w-0">
                <div className="w-14 h-14 rounded-xl bg-slate-100 overflow-hidden shrink-0 border border-slate-200 shadow-sm">
                  <img
                    src={
                      activeSpace.images && activeSpace.images.length > 0
                        ? activeSpace.images[0]
                        : 'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?auto=format&fit=crop&w=400&q=80'
                    }
                    alt={activeSpace.title}
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5">
                    <h4 className="font-extrabold text-slate-900 text-sm truncate">{activeSpace.title}</h4>
                    {activeSpace.isEvCharging && (
                      <span className="p-0.5 bg-emerald-100 text-emerald-700 rounded" title="EV Fast Charger">
                        <Zap className="w-3 h-3 fill-emerald-600" />
                      </span>
                    )}
                  </div>
                  <p className="text-[11px] text-slate-500 line-clamp-1 mt-0.5 flex items-center gap-1">
                    <MapPin className="w-3 h-3 text-slate-400 shrink-0" />
                    {activeSpace.address}
                  </p>
                  <div className="flex items-center gap-2 mt-1.5">
                    <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-md bg-purple-100 text-purple-700">
                      ₹{activeSpace.pricing.hourly}/hr
                    </span>
                    <span className="text-[10px] font-bold text-slate-500">
                      3D Plot: {activeSpace.totalLandSqMeters || 150}m²
                    </span>
                  </div>
                </div>
              </div>

              {/* Close Button ('X') */}
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setSelectedSpace(null);
                  setHoveredSpace(null);
                  setIsCardDismissed(true);
                }}
                className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors shrink-0"
                title="Close Details Card"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Real-time Slot Availability Gauge */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 space-y-1.5">
              <div className="flex justify-between text-xs font-bold">
                <span className="text-slate-600">Real-Time Slot Availability:</span>
                <span className={activeSpace.availableSlots > 0 ? 'text-emerald-700 font-extrabold' : 'text-rose-600 font-extrabold'}>
                  {activeSpace.availableSlots} of {activeSpace.totalSlots} Slots Free
                </span>
              </div>
              <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-300 ${
                    activeSpace.availableSlots > 0 ? 'bg-gradient-to-r from-emerald-500 to-emerald-400' : 'bg-rose-500'
                  }`}
                  style={{
                    width: `${Math.min(100, (activeSpace.availableSlots / Math.max(1, activeSpace.totalSlots)) * 100)}%`,
                  }}
                />
              </div>
            </div>

            {/* Host Information */}
            <div className="flex items-center justify-between text-xs text-slate-600 px-1">
              <div>
                <span className="text-[10px] font-bold text-slate-400 uppercase block">SPACE MANAGER</span>
                <span className="font-bold text-slate-900">{activePartner.name}</span>
              </div>
              <div className="text-right">
                <span className="text-[10px] font-bold text-slate-400 uppercase block">PHONE</span>
                <span className="font-bold text-slate-900">{activePartner.phone}</span>
              </div>
            </div>

            {/* CALL & CHAT ACTION BUTTONS */}
            <div className="grid grid-cols-2 gap-2.5 pt-1">
              <button
                onClick={() => {
                  setCallModalSpace(activeSpace);
                  setIsCalling(true);
                }}
                className="py-2.5 px-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-md shadow-emerald-600/20 transition-all active:scale-95"
              >
                <Phone className="w-4 h-4" /> Call Host
              </button>

              <button
                onClick={() => setChatModalSpace(activeSpace)}
                className="py-2.5 px-3 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-md shadow-purple-600/20 transition-all active:scale-95"
              >
                <MessageSquare className="w-4 h-4" /> Live Chat
              </button>
            </div>
          </div>
        )}
      </div>

      {/* 4. Live Audio Call Modal */}
      {callModalSpace && (
        <Modal
          isOpen={Boolean(callModalSpace)}
          onClose={() => {
            setCallModalSpace(null);
            setIsCalling(false);
          }}
          title="Direct Host / Customer Audio Voice Call"
          subtitle={`Connecting to ${getPartnerInfo(callModalSpace.ownerId).name} (${callModalSpace.title})`}
          maxWidth="max-w-md"
        >
          <div className="text-center py-6 space-y-6">
            {/* Animated Call Pulse Ring */}
            <div className="relative mx-auto w-24 h-24 flex items-center justify-center">
              {isCalling && (
                <>
                  <div className="absolute inset-0 rounded-full bg-emerald-500/20 animate-ping" />
                  <div className="absolute -inset-3 rounded-full bg-emerald-500/10 animate-pulse" />
                </>
              )}
              <div className="w-20 h-20 rounded-full bg-emerald-600 text-white flex items-center justify-center shadow-xl shadow-emerald-600/30">
                <PhoneCall className="w-10 h-10 animate-bounce" />
              </div>
            </div>

            <div>
              <h4 className="text-lg font-extrabold text-slate-900">
                {getPartnerInfo(callModalSpace.ownerId).name}
              </h4>
              <p className="text-sm font-bold text-purple-700 mt-0.5">
                {getPartnerInfo(callModalSpace.ownerId).phone}
              </p>
              <p className="text-xs text-slate-400 mt-1">{callModalSpace.title}</p>
            </div>

            {/* Call status / timer */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 inline-block px-6">
              <span className="text-xs font-mono font-extrabold text-emerald-600">
                {isCalling ? `🟢 Live Call Connected • ${formatTimer(callTimer)}` : 'Call Ended'}
              </span>
            </div>

            {/* End Call Button */}
            <div>
              <button
                onClick={() => {
                  setIsCalling(false);
                  setCallModalSpace(null);
                }}
                className="w-full py-3 bg-rose-600 hover:bg-rose-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-rose-600/20 transition-colors"
              >
                <PhoneOff className="w-4 h-4" /> End Call
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* 5. Live Chat Modal */}
      {chatModalSpace && (
        <Modal
          isOpen={Boolean(chatModalSpace)}
          onClose={() => setChatModalSpace(null)}
          title={`Live Chat: ${getPartnerInfo(chatModalSpace.ownerId).name}`}
          subtitle={`Property: ${chatModalSpace.title}`}
          maxWidth="max-w-lg"
        >
          <div className="flex flex-col h-[400px]">
            {/* Messages Thread */}
            <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-slate-50/70 rounded-xl border border-slate-100">
              {chatMessages.map((msg, i) => (
                <div
                  key={i}
                  className={`flex flex-col ${msg.sender === 'admin' ? 'items-end' : 'items-start'}`}
                >
                  <div
                    className={`max-w-[80%] p-3 rounded-2xl text-xs font-medium ${
                      msg.sender === 'admin'
                        ? 'bg-purple-600 text-white rounded-br-none shadow-sm'
                        : 'bg-white text-slate-800 border border-slate-200 rounded-bl-none shadow-sm'
                    }`}
                  >
                    {msg.text}
                  </div>
                  <span className="text-[10px] text-slate-400 mt-1 px-1">{msg.time}</span>
                </div>
              ))}
            </div>

            {/* Message Input Bar */}
            <form onSubmit={handleSendMessage} className="mt-3 flex items-center gap-2">
              <input
                type="text"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                placeholder="Type your message to host..."
                className="flex-1 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-800 focus:outline-none focus:border-purple-500"
              />
              <button
                type="submit"
                className="p-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-xl shadow-md shadow-purple-600/20 transition-colors"
              >
                <Send className="w-4 h-4" />
              </button>
            </form>
          </div>
        </Modal>
      )}
    </div>
  );
};
